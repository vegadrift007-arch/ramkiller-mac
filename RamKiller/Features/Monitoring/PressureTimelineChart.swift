import SwiftUI
import Charts
import SwiftData

struct PressureTimelineChart: View {
    @Query private var snapshots: [MemorySnapshot]
    let windowHours: Int

    init(windowHours: Int = 1) {
        self.windowHours = windowHours
        let cutoff = Date().addingTimeInterval(-Double(windowHours) * 3600)
        let predicate = #Predicate<MemorySnapshot> { $0.timestamp >= cutoff }
        _snapshots = Query(filter: predicate, sort: \MemorySnapshot.timestamp)
    }

    private var rendered: [MemorySnapshot] { downsample(snapshots, target: 250) }

    var body: some View {
        Chart {
            ForEach(rendered) { snap in
                BarMark(
                    x: .value("Time", snap.timestamp),
                    y: .value("Level", snap.pressureLevel + 1)
                )
                .foregroundStyle(color(for: snap.pressureLevel))
            }
        }
        .chartYScale(domain: 0...3)
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks(values: .automatic) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.hour().minute())
            }
        }
        .frame(height: 60)
    }

    private func color(for level: Int) -> Color {
        switch level {
        case 0: return .green.opacity(0.4)
        case 1: return .yellow.opacity(0.6)
        default: return .red.opacity(0.7)
        }
    }
}
