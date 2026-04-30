import SwiftUI
import Charts
import SwiftData

struct PressureTimelineView: View {
    @Query private var snapshots: [MemorySnapshot]
    let days: Int

    init(days: Int) {
        self.days = days
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        let predicate = #Predicate<MemorySnapshot> { $0.timestamp >= cutoff }
        _snapshots = Query(filter: predicate, sort: \MemorySnapshot.timestamp)
    }

    private struct HourBucket: Identifiable {
        let id = UUID()
        let hour: Date
        let avgPressure: Double
    }

    private var buckets: [HourBucket] {
        let grouped = Dictionary(grouping: snapshots) { snap -> Date in
            let comp = Calendar.current.dateComponents([.year, .month, .day, .hour], from: snap.timestamp)
            return Calendar.current.date(from: comp) ?? snap.timestamp
        }
        return grouped.map { (hour, snaps) in
            let avg = snaps.map { Double($0.pressureLevel) }.reduce(0, +) / Double(max(snaps.count, 1))
            return HourBucket(hour: hour, avgPressure: avg)
        }
        .sorted { $0.hour < $1.hour }
    }

    var body: some View {
        if buckets.isEmpty {
            ContentUnavailableView("No data yet", systemImage: "clock", description: Text("Need to run for at least an hour to see trends."))
                .frame(height: 180)
        } else {
            Chart(buckets) { bucket in
                BarMark(
                    x: .value("Hour", bucket.hour, unit: .hour),
                    y: .value("Pressure", bucket.avgPressure)
                )
                .foregroundStyle(color(for: bucket.avgPressure))
            }
            .chartYScale(domain: 0...2)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 8))
            }
            .frame(height: 180)
        }
    }

    private func color(for level: Double) -> Color {
        switch level {
        case ..<0.5:  return .green
        case ..<1.5:  return .yellow
        default:      return .red
        }
    }
}
