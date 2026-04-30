import SwiftUI
import SwiftData

struct CulpritProcessesView: View {
    @Query private var snapshots: [ProcessSnapshot]
    let days: Int

    init(days: Int) {
        self.days = days
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        let predicate = #Predicate<ProcessSnapshot> { $0.timestamp >= cutoff }
        _snapshots = Query(filter: predicate, sort: \ProcessSnapshot.timestamp)
    }

    private struct ProcAgg: Identifiable {
        let id: String
        let name: String
        let totalRSS: Int64
        let appearances: Int
    }

    private var top10: [ProcAgg] {
        let grouped = Dictionary(grouping: snapshots) { $0.name }
        let aggregates = grouped.map { (name, snaps) in
            ProcAgg(
                id: name,
                name: name,
                totalRSS: snaps.map { $0.rssBytes }.reduce(0, +),
                appearances: snaps.count
            )
        }
        return aggregates.sorted { $0.totalRSS > $1.totalRSS }.prefix(10).map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading) {
            Text("Top processes by aggregated RSS").font(.headline)
            if top10.isEmpty {
                ContentUnavailableView("No data", systemImage: "list.dash")
                    .frame(minHeight: 280)
            } else {
                Table(top10) {
                    TableColumn("Name") { p in Text(p.name) }
                    TableColumn("Total RSS") { p in Text(ByteFormat.gb(p.totalRSS)).monospacedDigit() }
                    TableColumn("Sampled") { p in Text("\(p.appearances)").monospacedDigit() }
                }
                .frame(minHeight: 280)
            }
        }
    }
}
