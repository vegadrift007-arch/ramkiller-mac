import SwiftUI
import Charts

struct MemoryAreaChart: View {
    let data: [MemorySnapshot]

    var body: some View {
        Chart {
            ForEach(data) { snap in
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
        .chartYAxis { AxisMarks(format: Decimal.FormatStyle().precision(.fractionLength(0))) }
        .chartXAxis {
            AxisMarks(values: .automatic) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.hour().minute())
            }
        }
        .frame(minHeight: 220)
    }
}

/// Reduces an array to at most `target` items by uniform stride.
func downsample<T>(_ array: [T], target: Int) -> [T] {
    guard array.count > target else { return array }
    let step = Double(array.count) / Double(target)
    var result: [T] = []
    result.reserveCapacity(target)
    var i: Double = 0
    while Int(i) < array.count {
        result.append(array[Int(i)])
        i += step
    }
    return result
}
