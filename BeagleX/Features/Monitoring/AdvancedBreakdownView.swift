import SwiftUI

struct AdvancedBreakdownView: View {
    @EnvironmentObject private var coordinator: SamplingCoordinator

    var body: some View {
        if let m = coordinator.latestMemory {
            HStack(spacing: 14) {
                StatCard(
                    title: "Wired",
                    value: ByteFormat.gb(m.wiredBytes),
                    subtitle: String(localized: "kernel-locked"),
                    tint: Theme.purple
                )
                StatCard(
                    title: "Active",
                    value: ByteFormat.gb(m.activeBytes),
                    subtitle: String(localized: "recently used"),
                    tint: Theme.accent
                )
                StatCard(
                    title: "Inactive",
                    value: ByteFormat.gb(m.inactiveBytes),
                    subtitle: String(localized: "reclaimable"),
                    tint: Theme.warn
                )
                StatCard(
                    title: "Speculative",
                    value: ByteFormat.gb(m.speculativeBytes),
                    subtitle: String(localized: "prefetch"),
                    tint: Theme.inkSoft
                )
            }
        }
    }
}
