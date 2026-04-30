import AppKit
import SwiftData

@MainActor
enum SharedContainer {
    static var container: ModelContainer?
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var retentionTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("RamKiller launched")
        scheduleRetention()
        Task { @MainActor in
            await NotificationService.shared.requestAuthorization()
        }
    }

    /// Closing the main window does NOT terminate the app — menubar stays alive.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    private func scheduleRetention() {
        retentionTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { _ in
            Task { @MainActor in
                guard let container = SharedContainer.container else { return }
                let ctx = ModelContext(container)
                try? RetentionService().prune(in: ctx)
            }
        }
    }
}
