import SwiftUI

struct SmartKillBanner: View {
    @EnvironmentObject private var coordinator: SamplingCoordinator
    @State private var dismissed: Set<pid_t> = []
    @State private var error: String?
    @State private var showConfirm: Bool = false
    // Cached so SmartKillAnalyzer() isn't reinstantiated on every 2s memory tick.
    // Recomputed only when latestProcesses changes (every 60s).
    @State private var cachedCandidates: [ProcessReading] = []

    private var displayCandidates: [ProcessReading] {
        cachedCandidates.filter { !dismissed.contains($0.pid) }
    }

    var body: some View {
        let candidates = displayCandidates
        // Outer container always present so onAppear/onChange always fire,
        // regardless of whether the banner is visible.
        VStack(spacing: 0) {
            if !candidates.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "lightbulb")
                        Text("\(candidates.count) idle high-memory process\(candidates.count > 1 ? "es" : "")")
                            .font(.headline)
                        Spacer()
                        Button("Kill all") { showConfirm = true }
                            .buttonStyle(.borderedProminent)
                        Button("Dismiss") {
                            candidates.forEach { dismissed.insert($0.pid) }
                        }
                    }
                    ForEach(candidates.prefix(5)) { p in
                        HStack {
                            Text(p.name)
                            Spacer()
                            Text(ByteFormat.mb(p.rssBytes))
                                .foregroundStyle(.secondary)
                        }
                        .font(.caption)
                    }
                    if let e = error {
                        Text(e).font(.caption).foregroundStyle(.red)
                    }
                }
                .padding(12)
                .background(Color.yellow.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .alert("Kill \(candidates.count) processes?", isPresented: $showConfirm) {
                    Button("Cancel", role: .cancel) {}
                    Button("Kill all", role: .destructive) {
                        let snapshot = candidates
                        Task { await killAll(snapshot) }
                    }
                } message: {
                    Text(candidates.prefix(10)
                        .map { "• \($0.name) (\(ByteFormat.mb($0.rssBytes)))" }
                        .joined(separator: "\n"))
                }
            }
        }
        .onAppear { recompute() }
        .onChange(of: coordinator.latestProcesses.map(\.pid)) { _, _ in recompute() }
    }

    private func recompute() {
        cachedCandidates = SmartKillAnalyzer().candidates(from: coordinator.latestProcesses)
    }

    private func killAll(_ candidates: [ProcessReading]) async {
        for p in candidates {
            let r = kill(p.pid, SIGTERM)
            if r != 0 {
                error = "Failed to kill \(p.name): \(String(cString: strerror(errno)))"
                UserActionLog.shared.record(type: "smart_kill", target: "\(p.pid):\(p.name)", success: false, error: error)
            } else {
                UserActionLog.shared.record(type: "smart_kill", target: "\(p.pid):\(p.name)", success: true)
            }
        }
    }
}
