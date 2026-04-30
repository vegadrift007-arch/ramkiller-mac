import SwiftUI

struct AdvancedBreakdownView: View {
    @EnvironmentObject private var coordinator: SamplingCoordinator

    var body: some View {
        if let m = coordinator.latestMemory {
            VStack(alignment: .leading, spacing: 8) {
                Text("Advanced breakdown").font(.headline)
                HStack(spacing: 16) {
                    breakdown("Wired", bytes: m.wiredBytes)
                    breakdown("Active", bytes: m.activeBytes)
                    breakdown("Inactive", bytes: m.inactiveBytes)
                    breakdown("Speculative", bytes: m.speculativeBytes)
                }
                .font(.callout)
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func breakdown(_ title: String, bytes: Int64) -> some View {
        VStack(alignment: .leading) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(ByteFormat.gb(bytes)).monospacedDigit()
        }
    }
}
