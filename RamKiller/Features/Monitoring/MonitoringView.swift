import SwiftUI
import SwiftData

struct MonitoringView: View {
    @EnvironmentObject private var coordinator: SamplingCoordinator
    @Environment(\.modelContext) private var modelContext
    @AppStorage("monitoring.advanced") private var advanced: Bool = false
    @State private var windowHours: Int = 1
    // Single fetch owned here — charts receive plain arrays, no @Query inside them.
    // Capped at 300 rows to eliminate the 51k-row scan that caused scroll lag.
    @State private var chartData: [MemorySnapshot] = []

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
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
                VStack(alignment: .leading, spacing: 14) {
                    sectionHeader("Memory usage", value: "GB over time")
                    MemoryAreaChart(data: chartData).vqCard()
                }
                VStack(alignment: .leading, spacing: 14) {
                    sectionHeader("Pressure", value: "color = level")
                    PressureTimelineChart(data: chartData).vqCard()
                }
                VStack(alignment: .leading, spacing: 14) {
                    sectionHeader("Swap activity", value: "pages / second")
                    SwapRateChart(data: chartData).vqCard()
                }
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
        .onAppear { refreshChartData() }
        .onChange(of: windowHours) { _, _ in refreshChartData() }
        .task(id: windowHours) {
            // Refresh chart data every 30 seconds — charts don't need live 2s updates.
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                refreshChartData()
            }
        }
    }

    private func refreshChartData() {
        let cutoff = Date().addingTimeInterval(-Double(windowHours) * 3600)
        var descriptor = FetchDescriptor<MemorySnapshot>(
            predicate: #Predicate { $0.timestamp >= cutoff },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        // Fetch only the 300 most-recent rows, then reverse for chronological display.
        descriptor.fetchLimit = 300
        chartData = ((try? modelContext.fetch(descriptor)) ?? []).reversed()
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
                    subtitle: String(localized: "memory squeezed"),
                    tint: Theme.warn
                )
                StatCard(
                    title: "Total",
                    value: ByteFormat.gb(m.totalBytes),
                    subtitle: String(localized: "physical RAM"),
                    tint: Theme.inkSoft
                )
            }
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
        case 0: return String(localized: "Healthy")
        case 1: return String(localized: "Under pressure")
        default: return String(localized: "Critical")
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
        case 0: return AnyView(VQTag(text: String(localized: "Healthy"), color: Theme.accent))
        case 1: return AnyView(VQTag(text: String(localized: "Warn"), color: Theme.warn))
        default: return AnyView(VQTag(text: String(localized: "Critical"), color: Theme.danger))
        }
    }
}
