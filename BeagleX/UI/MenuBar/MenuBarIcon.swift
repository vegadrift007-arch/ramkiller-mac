import SwiftUI

struct MenuBarIcon: View {
    @EnvironmentObject private var coordinator: SamplingCoordinator

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(pressureColor)
                .frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .monospacedDigit()
        }
    }

    private var label: String {
        guard let mem = coordinator.latestMemory else { return "—" }
        return "\(Int(mem.usedPercent.rounded()))%"
    }

    private var pressureColor: Color {
        guard let mem = coordinator.latestMemory else { return Theme.mute }
        switch mem.pressureLevel {
        case 0: return Theme.accent
        case 1: return Theme.warn
        default: return Theme.danger
        }
    }
}
