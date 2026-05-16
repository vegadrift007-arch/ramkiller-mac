import SwiftUI

/// Compact horizontal view rendered inside the NSStatusItem button.
struct MenuBarStatsView: View {
    @EnvironmentObject private var coordinator: SamplingCoordinator

    var body: some View {
        HStack(spacing: 6) {
            statBlock(label: "CPU", value: "\(Int(coordinator.cpuPercent))%",
                      color: cpuColor(coordinator.cpuPercent))
            separator
            statBlock(label: "RAM", value: ramLabel, color: ramColor)
            separator
            netBlock(dot: Color(red: 1, green: 0.32, blue: 0.32),
                     speed: coordinator.networkDown)
            netBlock(dot: Color(red: 0.35, green: 0.65, blue: 1),
                     speed: coordinator.networkUp)
        }
        .padding(.horizontal, 6)
        .frame(height: 22)
    }

    private var separator: some View {
        Rectangle()
            .fill(Color.white.opacity(0.18))
            .frame(width: 1, height: 12)
    }

    private func statBlock(label: String, value: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.55))
            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(color)
        }
    }

    private func netBlock(dot: Color, speed: Double) -> some View {
        HStack(spacing: 3) {
            Circle().fill(dot).frame(width: 5, height: 5)
            Text(formatSpeed(speed))
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(.white)
        }
    }

    private var ramLabel: String {
        guard let m = coordinator.latestMemory else { return "—" }
        return "\(Int(m.usedPercent))%"
    }

    private var ramColor: Color {
        guard let m = coordinator.latestMemory else { return .white }
        return m.usedPercent > 85 ? Color(red: 1, green: 0.32, blue: 0.32)
             : m.usedPercent > 70 ? Color(red: 1, green: 0.65, blue: 0)
             : .white
    }

    private func cpuColor(_ pct: Double) -> Color {
        pct > 80 ? Color(red: 1, green: 0.32, blue: 0.32)
       : pct > 50 ? Color(red: 1, green: 0.65, blue: 0)
       : .white
    }

    private func formatSpeed(_ bps: Double) -> String {
        if bps >= 1_000_000 { return String(format: "%.1fM", bps / 1_000_000) }
        if bps >= 1_000     { return String(format: "%.0fK", bps / 1_000) }
        return "0K"
    }
}
