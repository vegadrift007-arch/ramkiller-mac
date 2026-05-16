import SwiftUI
import Charts
import SwiftData

struct PressureTimelineView: View {
    @Query(sort: \MemorySnapshot.timestamp) private var allSnapshots: [MemorySnapshot]
    let days: Int

    init(days: Int) {
        self.days = days
    }

    /// Filter at body-time so cutoff is always fresh.
    private var snapshots: [MemorySnapshot] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date.distantPast
        return allSnapshots.filter { $0.timestamp >= cutoff }
    }

    private struct Bucket: Identifiable {
        let id = UUID()
        let start: Date
        let end: Date
        let avgPressure: Double?     // nil = no data sampled in this period
        let sampleCount: Int
    }

    /// All buckets in the [now-days, now] range — including empty ones (gray "no data")
    private var buckets: [Bucket] {
        let now = Date()
        let cal = Calendar.current
        let start = cal.date(byAdding: .day, value: -days, to: now)!

        // Bucket size: hour for ≤ 1d, otherwise 6h chunks for 7d/30d so the timeline is
        // legible without 720 cells.
        let bucketSeconds: TimeInterval = days <= 1 ? 3600 : (days <= 7 ? 3 * 3600 : 12 * 3600)

        // Group snapshots by their bucket start
        let grouped = Dictionary(grouping: snapshots) { snap -> Date in
            let intervalSinceStart = snap.timestamp.timeIntervalSince(start)
            let bucketIndex = floor(intervalSinceStart / bucketSeconds)
            return start.addingTimeInterval(bucketIndex * bucketSeconds)
        }

        var result: [Bucket] = []
        var t = start
        while t < now {
            let snaps = grouped[t] ?? []
            let avg: Double? = snaps.isEmpty
                ? nil
                : snaps.map { Double($0.pressureLevel) }.reduce(0, +) / Double(snaps.count)
            result.append(Bucket(
                start: t,
                end: t.addingTimeInterval(bucketSeconds),
                avgPressure: avg,
                sampleCount: snaps.count
            ))
            t = t.addingTimeInterval(bucketSeconds)
        }
        return result
    }

    var body: some View {
        if snapshots.isEmpty {
            ContentUnavailableView(
                "No data yet",
                systemImage: "clock",
                description: Text("App needs to run for at least a few minutes to show trends.")
            )
            .frame(height: 200)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                summaryRow
                heatmap
                legend
            }
        }
    }

    private var summaryRow: some View {
        let totalSamples = snapshots.count
        let pressureSamples = snapshots.filter { $0.pressureLevel > 0 }.count
        let pressureRate = totalSamples > 0 ? Double(pressureSamples) / Double(totalSamples) * 100 : 0
        let avgUnusedGB = snapshots.map { Double($0.unusedBytes) / 1_073_741_824 }.reduce(0, +) / Double(max(totalSamples, 1))

        return HStack(spacing: 24) {
            stat("Samples", value: "\(totalSamples)")
            stat("Pressure events", value: "\(pressureSamples) (\(String(format: "%.1f", pressureRate))%)")
            stat("Avg unused", value: String(format: "%.1f GB", avgUnusedGB))
            Spacer()
        }
        .padding(.horizontal, 4)
    }

    private func stat(_ title: LocalizedStringKey, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.callout).fontWeight(.medium).monospacedDigit()
        }
    }

    private var heatmap: some View {
        Chart(buckets) { bucket in
            RectangleMark(
                xStart: .value("Start", bucket.start),
                xEnd: .value("End", bucket.end),
                yStart: .value("Top", 0),
                yEnd: .value("Bottom", 1)
            )
            .foregroundStyle(color(for: bucket))
        }
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: days <= 1 ? 6 : 5)) { value in
                AxisGridLine()
                AxisValueLabel(format: dateFormat)
            }
        }
        .frame(height: 80)
        .padding(.horizontal, 4)
    }

    private var dateFormat: Date.FormatStyle {
        if days <= 1 {
            return .dateTime.hour()
        } else {
            return .dateTime.month(.abbreviated).day()
        }
    }

    private var legend: some View {
        HStack(spacing: 16) {
            legendItem(color: .gray.opacity(0.2), label: "No data")
            legendItem(color: .green.opacity(0.5), label: "Healthy")
            legendItem(color: .yellow.opacity(0.7), label: "Warning")
            legendItem(color: .red.opacity(0.8), label: "Critical")
            Spacer()
        }
        .font(.caption)
        .padding(.horizontal, 4)
    }

    private func legendItem(color: Color, label: LocalizedStringKey) -> some View {
        HStack(spacing: 4) {
            Rectangle().fill(color).frame(width: 12, height: 12).cornerRadius(2)
            Text(label).foregroundStyle(.secondary)
        }
    }

    private func color(for bucket: Bucket) -> Color {
        guard let level = bucket.avgPressure else {
            return .gray.opacity(0.15)
        }
        switch level {
        case ..<0.3:  return .green.opacity(0.6)
        case ..<1.3:  return .yellow.opacity(0.7)
        default:      return .red.opacity(0.85)
        }
    }
}
