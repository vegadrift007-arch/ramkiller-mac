import SwiftUI

struct SmartKillBanner: View {
    @EnvironmentObject private var coordinator: SamplingCoordinator
    @State private var dismissed: Set<pid_t> = []
    @State private var error: String?

    private var candidates: [ProcessReading] {
        SmartKillAnalyzer().candidates(from: coordinator.latestProcesses)
            .filter { !dismissed.contains($0.pid) }
    }

    var body: some View {
        if !candidates.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "lightbulb")
                    Text("\(candidates.count) idle high-memory process\(candidates.count > 1 ? "es" : "")")
                        .font(.headline)
                    Spacer()
                    Button("Kill all") { Task { await killAll() } }
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
        }
    }

    private func killAll() async {
        for p in candidates {
            let r = kill(p.pid, SIGTERM)
            if r != 0 {
                error = "Failed to kill \(p.name): \(String(cString: strerror(errno)))"
            }
        }
    }
}
