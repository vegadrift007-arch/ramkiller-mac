import SwiftUI
import Darwin
import Shared

struct ProcessesView: View {
    @EnvironmentObject private var coordinator: SamplingCoordinator
    @State private var search: String = ""
    @State private var selectedPID: pid_t?
    @State private var showAll: Bool = false
    @State private var fullList: [ProcessReading] = []
    @State private var killContext: KillConfirmContext?
    @State private var killError: String?

    private var visible: [ProcessReading] {
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
            // Top bar
            HStack(spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass").foregroundStyle(Theme.mute).font(.caption)
                    TextField("Search processes", text: $search)
                        .textFieldStyle(.plain)
                        .font(Theme.bodyText)
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Theme.cardBg)
                .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(Theme.line))
                .clipShape(RoundedRectangle(cornerRadius: 7))
                .frame(maxWidth: 280)

                Toggle("All processes", isOn: $showAll)
                    .toggleStyle(.checkbox)
                    .foregroundStyle(Theme.inkSoft)
                    .font(Theme.caption)
                    .onChange(of: showAll) { _, newValue in
                        if newValue { refreshFullList() }
                    }
                Button("Refresh") { refreshFullList() }
                    .buttonStyle(.borderless)
                    .foregroundStyle(Theme.accent)
                    .font(Theme.caption)
                Spacer()
                VQTag(text: "\(visible.count) procs", color: Theme.inkSoft)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Theme.bg2)

            Divider().background(Theme.line)

            HStack(spacing: 0) {
                Table(visible, selection: $selectedPID) {
                    TableColumn("Name") { p in
                        HStack {
                            Text(p.name).foregroundStyle(Theme.ink).lineLimit(1)
                            Spacer()
                            killButton(for: p)
                        }
                    }
                    .width(min: 200, ideal: 260)

                    TableColumn("PID") { p in
                        Text("\(p.pid)").font(Theme.mono(11)).foregroundStyle(Theme.inkSoft)
                    }.width(70)

                    TableColumn("RSS") { p in
                        Text(ByteFormat.mb(p.rssBytes))
                            .font(Theme.mono(12))
                            .foregroundStyle(p.rssBytes > 500_000_000 ? Theme.warn : Theme.inkSoft)
                    }.width(80)

                    TableColumn("User") { p in
                        Text(p.user)
                            .font(Theme.mono(11))
                            .foregroundStyle(p.user == NSUserName() ? Theme.accent : Theme.mute)
                    }.width(100)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .scrollContentBackground(.hidden)
                .background(Theme.bg)
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

                Divider().background(Theme.line)

                Group {
                    if let p = selected {
                        ProcessDetailView(process: p)
                    } else {
                        ContentUnavailableView("Select a process", systemImage: "arrow.left")
                    }
                }
                .frame(minWidth: 280, idealWidth: 340, maxWidth: 420)
                .frame(maxHeight: .infinity)
                .background(Theme.bg2)
            }
        }
        .background(Theme.bg)
        .navigationTitle("Processes")
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
        let isOwn = (p.user == NSUserName())
        Button {
            killContext = KillConfirmContext(process: p, force: false)
        } label: {
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(isOwn ? Theme.danger : Theme.warn)
                .font(.callout)
        }
        .buttonStyle(.borderless)
        .help(isOwn ? "Kill (SIGTERM)" : "Kill via privileged helper")
    }

    private func performKill(process: ProcessReading, force: Bool) {
        let signal: Int32 = force ? SIGKILL : SIGTERM
        let actionType = force ? "force_kill" : "kill"
        let target = "\(process.pid):\(process.name)"

        if process.user == NSUserName() {
            let result = kill(process.pid, signal)
            if result == 0 {
                UserActionLog.shared.record(type: actionType, target: target, success: true)
            } else {
                let err = String(cString: strerror(errno))
                killError = "kill(\(process.pid), \(signal)) failed: \(err)"
                UserActionLog.shared.record(type: actionType, target: target, success: false, error: err)
            }
        } else {
            Task {
                do {
                    let result = try await HelperBridge.shared.send(.killProcess(pid: process.pid, signal: signal))
                    switch result {
                    case .success:
                        UserActionLog.shared.record(type: actionType, target: target, success: true)
                    case .denied(let r):
                        killError = "Denied: \(r)"
                        UserActionLog.shared.record(type: actionType, target: target, success: false, error: r)
                    case .failed(let e):
                        killError = e
                        UserActionLog.shared.record(type: actionType, target: target, success: false, error: e)
                    }
                } catch {
                    killError = error.localizedDescription
                    UserActionLog.shared.record(type: actionType, target: target, success: false, error: error.localizedDescription)
                }
            }
        }
    }

    private func refreshFullList() {
        fullList = ProcessService().readAll().sorted { $0.rssBytes > $1.rssBytes }
    }
}
