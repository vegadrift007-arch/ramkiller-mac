import SwiftUI
import SwiftData

struct AlertHistoryView: View {
    @Query(sort: \AlertEvent.timestamp, order: .reverse) private var events: [AlertEvent]

    var body: some View {
        if events.isEmpty {
            ContentUnavailableView("No alerts yet", systemImage: "bell.slash", description: Text("Alerts appear here when memory thresholds are crossed."))
                .frame(minHeight: 280)
        } else {
            Table(events) {
                TableColumn("Time") { e in Text(e.timestamp.formatted(date: .abbreviated, time: .standard)) }
                TableColumn("Level") { e in
                    Label(e.level.label, systemImage: e.level.icon)
                }
                TableColumn("Trigger") { e in Text(e.trigger) }
            }
            .frame(minHeight: 280)
        }
    }
}
