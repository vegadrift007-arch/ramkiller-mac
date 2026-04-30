import SwiftUI

@main
struct RamKillerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Window("RamKiller", id: "main") {
            MainContentView()
                .frame(minWidth: 900, minHeight: 600)
        }
        .windowToolbarStyle(.unified)

        MenuBarExtra {
            MenuBarView()
        } label: {
            Image(systemName: "memorychip")
        }
        .menuBarExtraStyle(.window)
    }
}
