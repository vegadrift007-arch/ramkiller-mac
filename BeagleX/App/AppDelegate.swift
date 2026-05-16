import AppKit
import SwiftData

@MainActor
enum SharedContainer {
    static var container: ModelContainer?
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var retentionTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("BeagleX launched")
        scheduleRetention()
        Task { @MainActor in
            await NotificationService.shared.requestAuthorization()
        }
    }

    /// Closing the main window does NOT terminate the app — menubar stays alive.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    @objc func openMainWindow() {
        if let win = NSApp.windows.first(where: { $0.identifier?.rawValue == "main" }) {
            win.makeKeyAndOrderFront(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Hourly retention prune. Runs the SwiftData work off the main thread so
    /// large delete batches never block the UI.
    private func scheduleRetention() {
        retentionTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { _ in
            Task.detached(priority: .background) {
                guard let container = await SharedContainer.container else { return }
                let ctx = ModelContext(container)
                try? RetentionService().prune(in: ctx)
            }
        }
    }
}
