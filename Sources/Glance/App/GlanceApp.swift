import SwiftUI

@main
struct GlanceApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = TickerStore()
    @StateObject private var updater = Updater()

    var body: some Scene {
        MenuBarExtra {
            MenuContentView()
                .environmentObject(store)
                .environmentObject(updater)
        } label: {
            if store.instruments.isEmpty {
                // Nothing selected: keep a small icon so the dropdown stays reachable.
                Image(systemName: "chart.line.uptrend.xyaxis")
            } else {
                Text(store.menuBarTitle)
                    .monospacedDigit()
            }
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu-bar-only app: no Dock icon, no main window (also set via LSUIElement in the bundle).
        NSApp.setActivationPolicy(.accessory)
    }
}
