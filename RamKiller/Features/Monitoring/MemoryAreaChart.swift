import SwiftUI
import Charts
import SwiftData

struct MemoryAreaChart: View {
    @Query(sort: \MemorySnapshot.timestamp) private var snapshots: [MemorySnapshot]
    let windowHours: Int

    init(windowHours: Int = 1) {
        let cutoff = Date().addingTimeInterval(-Double(windowHours) * 3600)
        let predicate = #Predicate<MemorySnapshot> { $0.timestamp >= cutoff }
        _snapshots = Query(filter: predicate, sort: \MemorySnapshot.timestamp)
        self.windowHours = windowHours
    }

    var body: some View {
        Chart {
            ForEach(snapshots) { snap in
                AreaMark(
                    x: .value("Time", snap.timestamp),
                    y: .value("Used", Double(snap.usedBytes) / 1_073_741_824)
                )
                .foregroundStyle(by: .value("Series", "Used"))
                AreaMark(
                    x: .value("Time", snap.timestamp),
                    y: .value("Compressor", Double(snap.compressorBytes) / 1_073_741_824)
                )
                .foregroundStyle(by: .value("Series", "Compressor"))
            }
        }
        .chartForegroundStyleScale([
            "Used": Color.accentColor,
            "Compressor": Color.orange
        ])
        .chartYAxis {
            AxisMarks(format: Decimal.FormatStyle().precision(.fractionLength(0)))
        }
        .chartXAxis {
            AxisMarks(values: .automatic) { value in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.hour().minute())
            }
        }
        .frame(minHeight: 220)
    }
}
