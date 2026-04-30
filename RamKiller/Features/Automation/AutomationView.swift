import SwiftUI

struct AutomationView: View {
    @State private var days: Int = 7
    @State private var tab: Tab = .timeline

    enum Tab: String, CaseIterable, Identifiable {
        case timeline, culprits, alerts, actions
        var id: String { rawValue }
        var label: String {
            switch self {
            case .timeline: return "Pressure Timeline"
            case .culprits: return "Culprit Processes"
            case .alerts:   return "Alert History"
            case .actions:  return "User Actions"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Sticky top bar — View tabs + Range picker on a single row
            HStack(spacing: 12) {
                Picker("", selection: $tab) {
                    ForEach(Tab.allCases) { t in Text(t.label).tag(t) }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: .infinity)
                .labelsHidden()

                Picker("", selection: $days) {
                    Text("7d").tag(7)
                    Text("30d").tag(30)
                }
                .pickerStyle(.segmented)
                .frame(width: 100)
                .labelsHidden()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // Content
            ScrollView {
                Group {
                    switch tab {
                    case .timeline: PressureTimelineView(days: days)
                    case .culprits: CulpritProcessesView(days: days)
                    case .alerts:   AlertHistoryView()
                    case .actions:  UserActionHistoryView()
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Automation")
    }
}
