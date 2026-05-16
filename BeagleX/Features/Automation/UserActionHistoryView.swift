import SwiftUI
import SwiftData

struct UserActionHistoryView: View {
    @Query(sort: \UserAction.timestamp, order: .reverse) private var actions: [UserAction]

    var body: some View {
        if actions.isEmpty {
            ContentUnavailableView("No actions yet", systemImage: "list.dash", description: Text("Your kill / purge / clean actions show up here."))
                .frame(minHeight: 280)
        } else {
            Table(actions) {
                TableColumn("Time") { a in Text(a.timestamp.formatted(date: .abbreviated, time: .shortened)) }
                TableColumn("Type") { a in Text(a.actionType) }
                TableColumn("Target") { a in Text(a.targetIdentifier ?? "-") }
                TableColumn("Result") { a in
                    if a.success {
                        HStack {
                            Image(systemName: "checkmark.circle").foregroundStyle(.green)
                            Text("OK").font(.caption)
                        }
                    } else {
                        HStack {
                            Image(systemName: "xmark.circle").foregroundStyle(.red)
                            Text(a.errorText ?? "").font(.caption).lineLimit(1)
                        }
                    }
                }
            }
            .frame(minHeight: 280)
        }
    }
}
