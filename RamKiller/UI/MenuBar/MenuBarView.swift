import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var coordinator: SamplingCoordinator
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let m = coordinator.latestMemory {
                row("Used", value: ByteFormat.gb(m.usedBytes) + " / " + ByteFormat.gb(m.totalBytes))
                row("Unused", value: ByteFormat.gb(m.unusedBytes), badge: pressureBadge(m.pressureLevel))
                row("Compressor", value: ByteFormat.gb(m.compressorBytes))
                if m.swapOutPagesPerSec > 0 {
                    row("Swap out", value: "\(Int(m.swapOutPagesPerSec)) p/s", badge: AnyView(Text("⚠️")))
                }
            } else {
                Text("Sampling…").foregroundStyle(.secondary)
            }

            Divider()

            if !coordinator.latestProcesses.isEmpty {
                Text("Top 5 by RSS").font(.caption).foregroundStyle(.secondary)
                ForEach(coordinator.latestProcesses.prefix(5)) { p in
                    HStack {
                        Text(p.name).lineLimit(1).truncationMode(.tail)
                        Spacer()
                        Text(ByteFormat.mb(p.rssBytes)).foregroundStyle(.secondary)
                    }
                    .font(.caption)
                }
                Divider()
            }

            PurgeButton(style: .compact)

            Divider()

            Button("Open Main Window") { openWindow(id: "main") }
            Button("Quit") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        }
        .padding(12)
        .frame(width: 280)
    }

    private func row(_ title: String, value: String, badge: AnyView? = nil) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(value).monospacedDigit()
            if let badge { badge }
        }
        .font(.body)
    }

    private func pressureBadge(_ level: Int) -> AnyView {
        switch level {
        case 0: return AnyView(Text("🟢").font(.caption))
        case 1: return AnyView(Text("🟡").font(.caption))
        default: return AnyView(Text("🔴").font(.caption))
        }
    }
}
