import SwiftUI
import Charts
import SwiftData

struct SwapRateChart: View {
    @Query(sort: \MemorySnapshot.timestamp) private var snapshots: [MemorySnapshot]

    init(windowHours: Int = 1) {
        let cutoff = Date().addingTimeInterval(-Double(windowHours) * 3600)
        let predicate = #Predicate<MemorySnapshot> { $0.timestamp >= cutoff }
        _snapshots = Query(filter: predicate, sort: \MemorySnapshot.timestamp)
    }

    var body: some View {
        Chart {
            ForEach(snapshots) { snap in
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
