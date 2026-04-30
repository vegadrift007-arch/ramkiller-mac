import SwiftUI
import Combine
import Shared

struct PurgeButton: View {
    @StateObject private var cooldown = PurgeCooldown(cooldownSeconds: 60)
    @ObservedObject private var helper = HelperManager.shared
    @State private var inFlight = false
    @State private var lastError: String?
    @State private var tick: TimeInterval = 0
    let style: Style

    enum Style { case prominent, compact }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Group {
                if style == .prominent {
                    Button(action: fire) { content }
                        .buttonStyle(.borderedProminent)
                } else {
                    Button(action: fire) { content }
                        .buttonStyle(.bordered)
                }
            }
            .disabled(inFlight || !cooldown.isAllowed() || helper.status != .enabled)

            if let e = lastError {
                Text(e).font(.caption).foregroundStyle(.red).lineLimit(2)
            }
            if helper.status != .enabled {
                Text("Helper not enabled (Settings → Privileged Helper)")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            tick = Date().timeIntervalSince1970
        }
    }

    @ViewBuilder
    private var content: some View {
        if inFlight {
            ProgressView().controlSize(.small)
        } else if !cooldown.isAllowed() {
            Text(String(format: "Purge (%.0fs)", cooldown.remainingSeconds()))
        } else {
            Label("Purge Memory", systemImage: "trash")
        }
    }

    private func fire() {
        inFlight = true
        lastError = nil
        Task {
            do {
                let result = try await HelperBridge.shared.send(.purgeMemory)
                switch result {
                case .success:
                    cooldown.markFired()
                    UserActionLog.shared.record(type: "purge", success: true)
                case .denied(let r):
                    lastError = "Denied: \(r)"
                    UserActionLog.shared.record(type: "purge", success: false, error: r)
                case .failed(let e):
                    lastError = e
                    UserActionLog.shared.record(type: "purge", success: false, error: e)
                }
            } catch {
                lastError = error.localizedDescription
                UserActionLog.shared.record(type: "purge", success: false, error: error.localizedDescription)
            }
            inFlight = false
        }
    }
}
