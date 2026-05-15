import SwiftUI
import Charts

struct SwapRateChart: View {
    let data: [MemorySnapshot]

    var body: some View {
        Chart {
            ForEach(data) { snap in
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
