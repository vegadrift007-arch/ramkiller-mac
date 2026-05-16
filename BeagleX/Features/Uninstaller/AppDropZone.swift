import SwiftUI
import UniformTypeIdentifiers

struct AppDropZone: View {
    let onDrop: (URL) -> Void
    @State private var hover = false

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "arrow.down.app")
                .font(.title2)
                .foregroundStyle(hover ? Theme.accent : Theme.mute)
            Text("Drop a .app here")
                .font(Theme.caption)
                .foregroundStyle(hover ? Theme.accent : Theme.mute)
        }
        .frame(maxWidth: .infinity, minHeight: 64)
        .background(hover ? Theme.accent.opacity(0.08) : Color.clear)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(
                    hover ? Theme.accent : Theme.line,
                    style: StrokeStyle(lineWidth: 1, dash: [5])
                )
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
