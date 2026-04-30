import SwiftUI
import AppKit

struct ScanScopeSettings: View {
    @ObservedObject var store = ScanScopeStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Scan locations").font(.headline)
                Spacer()
                Button("Add Folder") { addFolder() }
                Button("Reset") { store.reset() }
            }
            ForEach(store.folders, id: \.self) { url in
                HStack {
                    Image(systemName: "folder")
                    Text(url.path)
                        .font(.caption.monospaced())
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Button { store.remove(url) } label: {
                        Image(systemName: "xmark.circle")
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func addFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        if panel.runModal() == .OK {
            for url in panel.urls { store.add(url) }
        }
    }
}
