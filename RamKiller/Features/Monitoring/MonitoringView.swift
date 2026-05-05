import SwiftUI

struct MonitoringView: View {
    @EnvironmentObject private var coordinator: SamplingCoordinator
    @AppStorage("monitoring.advanced") private var advanced: Bool = false
    @State private var windowHours: Int = 1

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                heroBlock
                SmartKillBanner()
                statCardsRow
                if advanced {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Kernel breakdown").vqEyebrow()
                        AdvancedBreakdownView()
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
                chartsSection
            }
            .padding(24)
        }
        .background(Theme.bg)
        .toolbarBackground(Theme.bg, for: .windowToolbar)
        .toolbarBackground(.visible, for: .windowToolbar)
        .navigationTitle("Memory")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                PurgeButton(style: .prominent)
            }
            ToolbarItem {
                Picker("", selection: $windowHours) {
                    Text("1h").tag(1)
                    Text("6h").tag(6)
                    Text("24h").tag(24)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            ToolbarItem {
                Toggle("Advanced", isOn: $advanced.animation(.easeInOut(duration: 0.2)))
            }
        }
    }

    @ViewBuilder
    private var heroBlock: some View {
        if let m = coordinator.latestMemory {
            HStack(alignment: .center, spacing: 32) {
                // Big used % display
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        VQPulseDot(color: pressureColor(m.pressureLevel))
                        Text("LIVE").vqEyebrow(color: pressureColor(m.pressureLevel))
                    }
                    Text("\(Int(m.usedPercent.rounded()))%")
                        .font(Theme.display(72))
                        .foregroundStyle(Theme.ink)
                        .monospacedDigit()
                    Text("of \(ByteFormat.gb(m.totalBytes)) used")
                        .font(Theme.bodyText)
                        .foregroundStyle(Theme.mute)
                }

                Spacer()

                // Pressure status box
                VStack(alignment: .trailing, spacing: 8) {
                    pressurePill(m.pressureLevel)
                    Text(ByteFormat.gb(m.unusedBytes) + " free")
                        .font(Theme.headline(20))
                        .foregroundStyle(pressureColor(m.pressureLevel))
                        .monospacedDigit()
                    if m.swapOutPagesPerSec > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.arrow.down")
                            Text("Swapping \(Int(m.swapOutPagesPerSec))/s")
                        }
                        .font(Theme.caption)
                        .foregroundStyle(Theme.danger)
                    }
                }
            }
            .padding(28)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(LinearGradient(
                        colors: [Theme.cardBg, Theme.cardBgHover],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(Theme.lineStrong, lineWidth: 1)
            )
        }
    }

    @ViewBuilder
    private var statCardsRow: some View {
        if let m = coordinator.latestMemory {
            HStack(spacing: 14) {
                StatCard(
                    title: "Used",
                    value: ByteFormat.gb(m.usedBytes),
                    subtitle: String(format: "%.0f%%", m.usedPercent),
                    tint: Theme.accent
                )
                StatCard(
                    title: "Unused",
                    value: ByteFormat.gb(m.unusedBytes),
                    subtitle: pressureLabel(m.pressureLevel),
                    tint: pressureColor(m.pressureLevel)
                )
                StatCard(
                    title: "Compressor",
                    value: ByteFormat.gb(m.compressorBytes),
                    subtitle: "memory squeezed",
                    tint: Theme.warn
                )
                StatCard(
                    title: "Total",
                    value: ByteFormat.gb(m.totalBytes),
                    subtitle: "physical RAM",
                    tint: Theme.inkSoft
                )
            }
        }
    }

    private var chartsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("Memory usage", value: "GB over time")
            MemoryAreaChart(windowHours: windowHours)
                .vqCard()

            sectionHeader("Pressure", value: "color = level")
            PressureTimelineChart(windowHours: windowHours)
                .vqCard()

            sectionHeader("Swap activity", value: "pages / second")
            SwapRateChart(windowHours: windowHours)
                .vqCard()
        }
    }

    private func sectionHeader(_ title: String, value: String) -> some View {
        HStack {
            Text(title).font(Theme.headline(16)).foregroundStyle(Theme.ink)
            Spacer()
            Text(value).vqEyebrow()
        }
    }

    private func pressureLabel(_ l: Int) -> String {
        switch l {
        case 0: return "Healthy"
        case 1: return "Under pressure"
        default: return "Critical"
        }
    }

    private func pressureColor(_ l: Int) -> Color {
        switch l {
        case 0: return Theme.accent
        case 1: return Theme.warn
        default: return Theme.danger
        }
    }

    private func pressurePill(_ l: Int) -> some View {
        switch l {
        case 0: return AnyView(VQTag(text: "Healthy", color: Theme.accent))
        case 1: return AnyView(VQTag(text: "Warn", color: Theme.warn))
        default: return AnyView(VQTag(text: "Critical", color: Theme.danger))
        }
    }
}
