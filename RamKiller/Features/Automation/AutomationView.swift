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
        VStack(alignment: .leading) {
            HStack {
                Picker("Range", selection: $days) {
                    Text("7 days").tag(7); Text("30 days").tag(30)
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
                Spacer()
            }
            .padding(.horizontal)

            Picker("View", selection: $tab) {
                ForEach(Tab.allCases) { t in Text(t.label).tag(t) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

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
        .navigationTitle("Automation")
    }
}
