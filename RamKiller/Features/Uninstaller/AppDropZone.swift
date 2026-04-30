import SwiftUI
import UniformTypeIdentifiers

struct AppDropZone: View {
    let onDrop: (URL) -> Void
    @State private var hover = false

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: "tray.and.arrow.down")
                .font(.title2)
            Text("Drop a .app bundle")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 80)
        .background(hover ? Color.accentColor.opacity(0.1) : Color.clear)
        .overlay(
            RoundedRectangle(cornerRadius: 8).strokeBorder(style: .init(lineWidth: 1, dash: [6]))
                .foregroundStyle(.secondary)
        )
        .onDrop(of: [.fileURL], isTargeted: $hover) { providers in
            for p in providers {
                _ = p.loadObject(ofClass: URL.self) { url, _ in
                    if let url, url.pathExtension == "app" {
                        DispatchQueue.main.async { onDrop(url) }
                    }
                }
            }
            return true
        }
    }
}
