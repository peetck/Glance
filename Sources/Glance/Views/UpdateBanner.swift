import SwiftUI

/// Shows update progress at the top of the dropdown. Renders nothing when idle.
struct UpdateBanner: View {
    @ObservedObject var updater: Updater

    var body: some View {
        switch updater.state {
        case .idle:
            EmptyView()
        case .checking:
            row(icon: nil) { Text("Checking for updates…") }
        case .upToDate:
            row(icon: "checkmark.circle.fill", tint: .green) {
                Text("Glance \(updater.currentVersion ?? "") is up to date.")
            }
        case .available(let release):
            available(release)
        case .downloading(let release):
            row(icon: nil) { Text("Downloading Glance \(release.version)…") }
        case .failed(let message, let release):
            VStack(alignment: .leading, spacing: 6) {
                row(icon: "exclamationmark.triangle.fill", tint: .orange) { Text(message) }
                HStack {
                    Spacer()
                    Button("Dismiss") { updater.dismiss() }
                    Button("Open Releases") { updater.openReleasePage(release) }
                }
                .controlSize(.small)
            }
            .bannerBackground()
        }
    }

    private func available(_ release: Updater.Release) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Glance \(release.version) is available").font(.callout.weight(.semibold))
                    HStack(spacing: 4) {
                        if let current = updater.currentVersion {
                            Text("You have \(current).")
                        }
                        Button("What's new") { updater.openReleasePage(release) }
                            .buttonStyle(.link)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            HStack {
                Button("Skip This Version") { updater.skip(release) }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Later") { updater.dismiss() }
                Button("Update & Restart") { Task { await updater.install(release) } }
                    .buttonStyle(.borderedProminent)
            }
            .controlSize(.small)
        }
        .bannerBackground()
    }

    private func row(icon: String?, tint: Color = .secondary, @ViewBuilder text: () -> Text) -> some View {
        HStack(spacing: 6) {
            if let icon {
                Image(systemName: icon).foregroundStyle(tint)
            } else {
                ProgressView().controlSize(.small)
            }
            text().font(.caption)
            Spacer(minLength: 0)
        }
        .bannerBackground()
    }
}

private extension View {
    func bannerBackground() -> some View {
        padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
    }
}
