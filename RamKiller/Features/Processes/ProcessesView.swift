import SwiftUI
import Darwin

struct ProcessesView: View {
    @EnvironmentObject private var coordinator: SamplingCoordinator
    @State private var search: String = ""
    @State private var selectedPID: pid_t?
    @State private var showAll: Bool = false
    @State private var fullList: [ProcessReading] = []
    @State private var killContext: KillConfirmContext?
    @State private var killError: String?

    private var visible: [ProcessReading] {
        // If user toggled "All processes" but fullList not yet populated, fall back to coordinator's Top 30
        // so the UI is never empty.
        let source: [ProcessReading]
        if showAll {
            source = fullList.isEmpty ? coordinator.latestProcesses : fullList
        } else {
            source = coordinator.latestProcesses
        }
        guard !search.isEmpty else { return source }
        return source.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    private var selected: ProcessReading? {
        guard let pid = selectedPID else { return nil }
        return visible.first { $0.pid == pid }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
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
                    TableColumn("Name") { p in
                        HStack {
                            Text(p.name).lineLimit(1)
                            Spacer()
                            killButton(for: p)
                        }
                    }
                    .width(min: 200, ideal: 260)

                    TableColumn("PID") { p in Text("\(p.pid)").monospacedDigit() }
                        .width(70)
                    TableColumn("RSS") { p in Text(ByteFormat.mb(p.rssBytes)).monospacedDigit() }
                        .width(80)
                    TableColumn("User") { p in Text(p.user) }
                        .width(90)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contextMenu(forSelectionType: pid_t.self) { selectedPIDs in
                    if let pid = selectedPIDs.first, let p = visible.first(where: { $0.pid == pid }) {
                        Button("Kill (SIGTERM)") {
                            killContext = KillConfirmContext(process: p, force: false)
                        }
                        Button("Force kill (SIGKILL)") {
                            killContext = KillConfirmContext(process: p, force: true)
                        }
                    }
                }

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
        .task(id: showAll) {
            if showAll {
                refreshFullList()
            }
        }
        .killConfirmAlert($killContext) { process, force in
            performKill(process: process, force: force)
        }
        .alert("Kill failed", isPresented: Binding(
            get: { killError != nil },
            set: { if !$0 { killError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: { Text(killError ?? "") }
    }

    @ViewBuilder
    private func killButton(for p: ProcessReading) -> some View {
        if p.user == NSUserName() {
            Button {
                killContext = KillConfirmContext(process: p, force: false)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
                    .imageScale(.large)
            }
            .buttonStyle(.borderless)
            .help("Kill (SIGTERM)")
        } else {
            Image(systemName: "lock.fill")
                .foregroundStyle(.orange)
                .imageScale(.large)
                .help("System process — needs helper (Phase 2 step 2)")
        }
    }

    private func performKill(process: ProcessReading, force: Bool) {
        let signal: Int32 = force ? SIGKILL : SIGTERM
        if process.user == NSUserName() {
            let result = kill(process.pid, signal)
            if result != 0 {
                killError = "kill(\(process.pid), \(signal)) failed: \(String(cString: strerror(errno)))"
            }
        } else {
            killError = "System processes need privileged helper (coming in Phase 2 step 2)"
        }
    }

    private func refreshFullList() {
        fullList = ProcessService().readAll().sorted { $0.rssBytes > $1.rssBytes }
    }
}
