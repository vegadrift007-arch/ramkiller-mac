import SwiftUI

struct MenuBarView: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("RamKiller")
                .font(.headline)
            Text("Phase 1 will fill these stats")
                .font(.caption)
                .foregroundStyle(.secondary)
            Divider()
            Button("Open Main Window") { openWindow(id: "main") }
            Button("Quit") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        }
        .padding(12)
        .frame(width: 240)
    }
}
