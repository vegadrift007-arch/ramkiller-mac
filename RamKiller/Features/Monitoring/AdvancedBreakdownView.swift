import SwiftUI

struct AdvancedBreakdownView: View {
    @EnvironmentObject private var coordinator: SamplingCoordinator

    var body: some View {
        if let m = coordinator.latestMemory {
            HStack(spacing: 14) {
                StatCard(
                    title: "Wired",
                    value: ByteFormat.gb(m.wiredBytes),
                    subtitle: "kernel-locked",
                    tint: Theme.purple
                )
                StatCard(
                    title: "Active",
                    value: ByteFormat.gb(m.activeBytes),
                    subtitle: "recently used",
                    tint: Theme.accent
                )
                StatCard(
                    title: "Inactive",
                    value: ByteFormat.gb(m.inactiveBytes),
                    subtitle: "reclaimable",
                    tint: Theme.warn
                )
                StatCard(
                    title: "Speculative",
                    value: ByteFormat.gb(m.speculativeBytes),
                    subtitle: "prefetch",
                    tint: Theme.inkSoft
                )
            }
        }
    }
}
