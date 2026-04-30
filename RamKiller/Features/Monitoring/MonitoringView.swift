import SwiftUI

struct MonitoringView: View {
    @EnvironmentObject private var coordinator: SamplingCoordinator
    @AppStorage("monitoring.advanced") private var advanced: Bool = false
    @State private var windowHours: Int = 1

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SmartKillBanner()
                statCardsRow
                chartsSection
                if advanced { AdvancedBreakdownView() }
            }
            .padding(16)
        }
        .navigationTitle("Memory")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                PurgeButton(style: .prominent)
            }
            ToolbarItem {
                Picker("Window", selection: $windowHours) {
                    Text("1h").tag(1)
                    Text("6h").tag(6)
                    Text("24h").tag(24)
                }
                .pickerStyle(.segmented)
            }
            ToolbarItem {
                Toggle("Advanced", isOn: $advanced)
            }
        }
    }

    @ViewBuilder
    private var statCardsRow: some View {
        if let m = coordinator.latestMemory {
            HStack(spacing: 12) {
                StatCard(
                    title: "Used",
                    value: ByteFormat.gb(m.usedBytes),
                    subtitle: String(format: "%.0f%%", m.usedPercent),
                    tint: .accentColor
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
                    subtitle: nil,
                    tint: .orange
                )
                StatCard(
                    title: "Total",
                    value: ByteFormat.gb(m.totalBytes),
                    subtitle: nil,
                    tint: .secondary
                )
            }
        } else {
            ProgressView().padding()
        }
    }

    private var chartsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Memory usage").font(.headline)
            MemoryAreaChart(windowHours: windowHours)
            Text("Pressure").font(.headline)
            PressureTimelineChart(windowHours: windowHours)
            Text("Swap activity (pages/sec)").font(.headline)
            SwapRateChart(windowHours: windowHours)
        }
    }

    private func pressureLabel(_ l: Int) -> String {
        switch l {
        case 0: return "🟢 OK"
        case 1: return "🟡 Warn"
        default: return "🔴 Critical"
        }
    }

    private func pressureColor(_ l: Int) -> Color {
        switch l {
        case 0: return .green
        case 1: return .yellow
        default: return .red
        }
    }
}
