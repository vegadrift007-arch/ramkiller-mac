import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var coordinator: SamplingCoordinator
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // header
            HStack {
                Text("RamKiller").font(Theme.headline(15))
                Spacer()
                if let m = coordinator.latestMemory {
                    pressureBadge(m.pressureLevel)
                }
            }

            // stats
            if let m = coordinator.latestMemory {
                VStack(spacing: 8) {
                    statRow("Used", value: ByteFormat.gb(m.usedBytes), accent: Theme.accent, fraction: m.usedPercent / 100)
                    statRow("Unused", value: ByteFormat.gb(m.unusedBytes), accent: pressureColor(m.pressureLevel))
                    statRow("Compressor", value: ByteFormat.gb(m.compressorBytes), accent: Theme.warn)
                    if m.swapOutPagesPerSec > 0 {
                        statRow("Swap out", value: "\(Int(m.swapOutPagesPerSec)) p/s", accent: Theme.danger)
                    }
                }
            } else {
                Text("Sampling…").foregroundStyle(Theme.mute)
            }

            Divider().background(Theme.line)

            // top processes
            if !coordinator.latestProcesses.isEmpty {
                Text("Top processes").vqEyebrow()
                VStack(spacing: 6) {
                    ForEach(coordinator.latestProcesses.prefix(5)) { p in
                        HStack {
                            Text(p.name)
                                .font(Theme.bodyText)
                                .lineLimit(1)
                                .truncationMode(.tail)
                            Spacer()
                            Text(ByteFormat.mb(p.rssBytes))
                                .font(Theme.mono(12))
                                .foregroundStyle(Theme.inkSoft)
                        }
                    }
                }

                Divider().background(Theme.line)
            }

            PurgeButton(style: .compact)

            HStack {
                Button("Open Window") { openWindow(id: "main") }
                    .buttonStyle(.borderless)
                    .foregroundStyle(Theme.inkSoft)
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
                    .buttonStyle(.borderless)
                    .foregroundStyle(Theme.mute)
                    .keyboardShortcut("q")
            }
            .font(Theme.caption)
        }
        .padding(14)
        .frame(width: 300)
        .background(Theme.bg)
    }

    private func statRow(_ title: LocalizedStringKey, value: String, accent: Color, fraction: Double? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title).font(Theme.caption).foregroundStyle(Theme.mute)
                Spacer()
                Text(value).font(Theme.mono(13)).foregroundStyle(accent)
            }
            if let f = fraction {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Theme.line)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(accent)
                            .frame(width: max(2, geo.size.width * f))
                    }
                }
                .frame(height: 4)
            }
        }
    }

    private func pressureBadge(_ level: Int) -> some View {
        switch level {
        case 0: return AnyView(VQTag(text: String(localized: "Healthy"), color: Theme.accent))
        case 1: return AnyView(VQTag(text: String(localized: "Warn"), color: Theme.warn))
        default: return AnyView(VQTag(text: String(localized: "Critical"), color: Theme.danger))
        }
    }

    private func pressureColor(_ level: Int) -> Color {
        switch level {
        case 0: return Theme.accent
        case 1: return Theme.warn
        default: return Theme.danger
        }
    }
}
