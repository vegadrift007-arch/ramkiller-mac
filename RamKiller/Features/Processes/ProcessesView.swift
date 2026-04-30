import SwiftUI

struct ProcessesView: View {
    @EnvironmentObject private var coordinator: SamplingCoordinator
    @State private var search: String = ""
    @State private var selectedPID: pid_t?
    @State private var showAll: Bool = false
    @State private var fullList: [ProcessReading] = []

    private var visible: [ProcessReading] {
        let source = showAll ? fullList : coordinator.latestProcesses
        guard !search.isEmpty else { return source }
        return source.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    private var selected: ProcessReading? {
        guard let pid = selectedPID else { return nil }
        return visible.first { $0.pid == pid }
    }

    var body: some View {
        HSplitView {
            VStack(spacing: 0) {
                Table(visible, selection: $selectedPID) {
                    TableColumn("Name") { p in Text(p.name) }
                        .width(min: 180, ideal: 220)
                    TableColumn("PID") { p in Text("\(p.pid)").monospacedDigit() }
                        .width(80)
                    TableColumn("RSS") { p in Text(ByteFormat.mb(p.rssBytes)).monospacedDigit() }
                        .width(80)
                    TableColumn("User") { p in Text(p.user) }
                        .width(90)
                }
                Divider()
                HStack {
                    TextField("Search", text: $search)
                        .textFieldStyle(.roundedBorder)
                    Toggle("All processes", isOn: $showAll)
                        .onChange(of: showAll) { _, newValue in
                            if newValue { refreshFullList() }
                        }
                    Button("Refresh") { refreshFullList() }
                }
                .padding(8)
            }
            .frame(minWidth: 480)

            Group {
                if let p = selected {
                    ProcessDetailView(process: p)
                } else {
                    ContentUnavailableView("Select a process", systemImage: "arrow.left")
                }
            }
            .frame(minWidth: 280)
        }
        .navigationTitle("Processes")
    }

    private func refreshFullList() {
        fullList = ProcessService().readAll().sorted { $0.rssBytes > $1.rssBytes }
    }
}
