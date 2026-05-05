import SwiftUI
import Charts
import SwiftData

struct SwapRateChart: View {
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
                LineMark(
                    x: .value("Time", snap.timestamp),
                    y: .value("Swap In", snap.swapInPagesPerSec),
                    series: .value("Series", "In")
                )
                .foregroundStyle(.blue)
                LineMark(
                    x: .value("Time", snap.timestamp),
                    y: .value("Swap Out", snap.swapOutPagesPerSec),
                    series: .value("Series", "Out")
                )
                .foregroundStyle(.red)
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.hour().minute())
            }
        }
        .frame(height: 140)
    }
}
