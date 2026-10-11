import AppKit
import Foundation

/// Checks GitHub Releases for a newer version and installs it in place, then relaunches.
/// A lightweight alternative to Sparkle: no dependency, works with the ad-hoc signed builds
/// and disk images that `.github/workflows/release.yml` publishes.
@MainActor
final class Updater: ObservableObject {
    struct Release: Equatable {
        let version: String
        let pageURL: URL
        /// The release's `.dmg` asset.
        let dmgURL: URL?
    }

    enum State: Equatable {
        case idle
        case checking
        case upToDate
        case available(Release)
        case downloading(Release)
        case failed(String, Release?)
    }

    nonisolated static let repo = "peetck/Glance"
    private static let checkInterval: TimeInterval = 24 * 60 * 60

    @Published private(set) var state: State = .idle
    @Published var checksAutomatically: Bool {
        didSet { defaults.set(checksAutomatically, forKey: Keys.auto) }
    }

    /// Nil when not running from a packaged .app (e.g. `swift run`), where there's nothing to replace.
    let currentVersion: String?

    private let defaults = UserDefaults.standard
    private var autoCheckLoop: Task<Void, Never>?

    private enum Keys {
        static let auto = "autoCheckUpdates"
        static let lastCheck = "lastUpdateCheck"
        static let skipped = "skippedUpdateVersion"
    }

    init() {
        let bundle = Bundle.main
        currentVersion = bundle.bundleURL.pathExtension == "app"
            ? bundle.infoDictionary?["CFBundleShortVersionString"] as? String
            : nil
        checksAutomatically = defaults.object(forKey: Keys.auto) as? Bool ?? true
        autoCheckLoop = Task { [weak self] in
            try? await Task.sleep(for: .seconds(10)) // let the app settle after launch
            while !Task.isCancelled {
                await self?.autoCheckIfDue()
                try? await Task.sleep(for: .seconds(60 * 60))
            }
        }
    }

    // MARK: Checking

    func checkForUpdates() async {
        await check(userInitiated: true)
    }

    private func autoCheckIfDue() async {
        guard checksAutomatically, state == .idle else { return }
        let last = defaults.object(forKey: Keys.lastCheck) as? Date ?? .distantPast
        guard Date().timeIntervalSince(last) >= Self.checkInterval else { return }
        await check(userInitiated: false)
    }

    private func check(userInitiated: Bool) async {
        if case .downloading = state { return }
        guard let currentVersion else {
            if userInitiated { state = .failed("Updates work only in the packaged app (./scripts/bundle.sh).", nil) }
            return
        }
        if userInitiated { state = .checking }
        do {
            let release = try await Self.fetchLatest()
            defaults.set(Date(), forKey: Keys.lastCheck)
            if Self.isNewer(release.version, than: currentVersion) {
                // A skipped version only stays quiet for automatic checks.
                if !userInitiated, defaults.string(forKey: Keys.skipped) == release.version { return }
                state = .available(release)
            } else if userInitiated {
                state = .upToDate
                try? await Task.sleep(for: .seconds(4))
                if state == .upToDate { state = .idle }
            }
        } catch {
            if userInitiated { state = .failed("Couldn't check for updates. Try again later.", nil) }
        }
    }

    func dismiss() {
        if case .downloading = state { return }
        state = .idle
    }

    func skip(_ release: Release) {
        defaults.set(release.version, forKey: Keys.skipped)
        state = .idle
    }

    func openReleasePage(_ release: Release?) {
        let url = release?.pageURL ?? URL(string: "https://github.com/\(Self.repo)/releases/latest")!
        NSWorkspace.shared.open(url)
    }

    // MARK: Installing

    func install(_ release: Release) async {
        guard let dmgURL = release.dmgURL else {
            openReleasePage(release)
            return
        }
        let installed = Bundle.main.bundleURL
        let folder = installed.deletingLastPathComponent()
        // Gatekeeper runs quarantined apps that were never moved from a read-only random path.
        guard !installed.path.contains("/AppTranslocation/") else {
            state = .failed("Move Glance to your Applications folder, reopen it, then update.", release)
            return
        }
        guard FileManager.default.isWritableFile(atPath: folder.path) else {
            state = .failed("Glance can't write to \(folder.path). Download the update manually.", release)
            return
        }
        state = .downloading(release)
        do {
            let fm = FileManager.default
            let work = fm.temporaryDirectory.appending(path: "GlanceUpdate-\(UUID().uuidString)")
            try fm.createDirectory(at: work, withIntermediateDirectories: true)

            let (downloaded, response) = try await URLSession.shared.download(from: dmgURL)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw UpdateError("Download failed.") }
            let dmg = work.appending(path: "update.dmg")
            try fm.moveItem(at: downloaded, to: dmg)
            try await Self.copyApp(fromDiskImage: dmg, to: work)

            // Only accept a bundle that is really Glance, at the advertised version, and intact.
            let newApp = work.appending(path: "Glance.app")
            let info = Bundle(url: newApp)?.infoDictionary
            guard info?["CFBundleIdentifier"] as? String == Bundle.main.bundleIdentifier,
                  info?["CFBundleShortVersionString"] as? String == release.version
            else { throw UpdateError("The downloaded app doesn't match this release.") }
            try await Self.run("/usr/bin/codesign", ["--verify", "--deep", newApp.path])

            try relaunch(replacing: installed, with: newApp, scratch: work)
        } catch {
            let message = (error as? UpdateError)?.message ?? error.localizedDescription
            state = .failed("Update failed: \(message)", release)
        }
    }

    /// Hands off to a small shell script that waits for this process to exit, swaps the bundle
    /// (restoring the old one if the copy fails), and opens the new version.
    private func relaunch(replacing installed: URL, with newApp: URL, scratch: URL) throws {
        let script = scratch.appending(path: "install.sh")
        try Self.installScript.write(to: script, atomically: true, encoding: .utf8)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = [script.path, String(ProcessInfo.processInfo.processIdentifier), installed.path, newApp.path, scratch.path]
        try process.run()
        NSApp.terminate(nil)
    }

    private static let installScript = """
    #!/bin/sh
    # Usage: install.sh <pid> <installed app> <new app> <scratch dir>
    pid="$1"; app="$2"; new="$3"; scratch="$4"
    while kill -0 "$pid" 2>/dev/null; do sleep 0.2; done
    backup="$app.old-$$"
    if mv "$app" "$backup"; then
        if ditto "$new" "$app"; then
            rm -rf "$backup"
        else
            rm -rf "$app"
            mv "$backup" "$app"
        fi
    fi
    xattr -dr com.apple.quarantine "$app" 2>/dev/null
    open "$app"
    rm -rf "$scratch"
    """

    // MARK: Helpers

    nonisolated static func isNewer(_ candidate: String, than current: String) -> Bool {
        func parts(_ v: String) -> [Int] {
            v.trimmingPrefix("v").split(separator: ".").map { Int($0.prefix(while: \.isNumber)) ?? 0 }
        }
        let a = parts(candidate), b = parts(current)
        for i in 0..<max(a.count, b.count) {
            let x = i < a.count ? a[i] : 0, y = i < b.count ? b[i] : 0
            if x != y { return x > y }
        }
        return false
    }

    private nonisolated static func fetchLatest() async throws -> Release {
        var request = URLRequest(url: URL(string: "https://api.github.com/repos/\(repo)/releases/latest")!)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Glance", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
        return Release(
            version: String(release.tag_name.trimmingPrefix("v")),
            pageURL: release.html_url,
            dmgURL: release.assets.first { $0.name.hasPrefix("Glance") && $0.name.hasSuffix(".dmg") }?.browser_download_url
        )
    }

    /// Mounts the disk image privately (no Finder window), copies `Glance.app` out, and unmounts.
    private nonisolated static func copyApp(fromDiskImage dmg: URL, to folder: URL) async throws {
        let mountPoint = folder.appending(path: "mnt")
        try FileManager.default.createDirectory(at: mountPoint, withIntermediateDirectories: true)
        try await run("/usr/bin/hdiutil", ["attach", "-quiet", "-nobrowse", "-noautoopen", "-readonly", "-mountpoint", mountPoint.path, dmg.path])
        do {
            try await run("/usr/bin/ditto", [mountPoint.appending(path: "Glance.app").path, folder.appending(path: "Glance.app").path])
        } catch {
            try? await run("/usr/bin/hdiutil", ["detach", "-quiet", "-force", mountPoint.path])
            throw error
        }
        try await run("/usr/bin/hdiutil", ["detach", "-quiet", mountPoint.path])
    }

    private nonisolated static func run(_ tool: String, _ args: [String]) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            let p = Process()
            p.executableURL = URL(fileURLWithPath: tool)
            p.arguments = args
            p.terminationHandler = { p in
                if p.terminationStatus == 0 {
                    cont.resume()
                } else {
                    cont.resume(throwing: UpdateError("\((tool as NSString).lastPathComponent) failed (\(p.terminationStatus))."))
                }
            }
            do { try p.run() } catch { cont.resume(throwing: error) }
        }
    }
}

private struct UpdateError: Error {
    let message: String
    init(_ message: String) { self.message = message }
}

private struct GitHubRelease: Decodable {
    struct Asset: Decodable {
        let name: String
        let browser_download_url: URL
    }

    let tag_name: String
    let html_url: URL
    let assets: [Asset]
}
