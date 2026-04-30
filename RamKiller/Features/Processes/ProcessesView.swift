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
        VStack(spacing: 0) {
            // Toolbar at top
            HStack {
                TextField("Search", text: $search)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 220)
                Toggle("All processes", isOn: $showAll)
                    .onChange(of: showAll) { _, newValue in
                        if newValue { refreshFullList() }
                    }
                Button("Refresh") { refreshFullList() }
                Spacer()
                Text("\(visible.count) processes")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // Master-detail
            HStack(spacing: 0) {
                Table(visible, selection: $selectedPID) {
                    TableColumn("Name") { p in Text(p.name).lineLimit(1) }
                        .width(min: 180, ideal: 240)
                    TableColumn("PID") { p in Text("\(p.pid)").monospacedDigit() }
                        .width(70)
                    TableColumn("RSS") { p in Text(ByteFormat.mb(p.rssBytes)).monospacedDigit() }
                        .width(80)
                    TableColumn("User") { p in Text(p.user) }
                        .width(90)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                Divider()

                Group {
                    if let p = selected {
                        ProcessDetailView(process: p)
                    } else {
                        ContentUnavailableView("Select a process", systemImage: "arrow.left")
                    }
                }
                .frame(minWidth: 260, idealWidth: 320, maxWidth: 400)
                .frame(maxHeight: .infinity)
            }
        }
        .navigationTitle("Processes")
    }

    private func refreshFullList() {
        fullList = ProcessService().readAll().sorted { $0.rssBytes > $1.rssBytes }
    }
}
