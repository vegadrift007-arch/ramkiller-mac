import SwiftUI

struct AutomationSettingsSection: View {
    @State private var config: ThresholdConfig = .load()
    @EnvironmentObject private var coordinator: SamplingCoordinator
    @State private var savedAt: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Automation").vqEyebrow()

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Theme.warn).font(.caption)
                    Text("Warning when Unused < \(config.warningUnusedGB, specifier: "%.1f") GB for \(config.warningHoldSeconds)s")
                        .font(Theme.caption)
                        .foregroundStyle(Theme.inkSoft)
                }
                Slider(value: $config.warningUnusedGB, in: 0.5...8.0, step: 0.5)
                    .tint(Theme.warn)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "flame.fill").foregroundStyle(Theme.danger).font(.caption)
                    Text("Critical when Unused < \(config.criticalUnusedGB, specifier: "%.1f") GB for \(config.criticalHoldSeconds)s")
                        .font(Theme.caption)
                        .foregroundStyle(Theme.inkSoft)
                }
                Slider(value: $config.criticalUnusedGB, in: 0.2...4.0, step: 0.1)
                    .tint(Theme.danger)
            }

            Toggle(isOn: $config.autoPurgeEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Auto-purge on threshold").foregroundStyle(Theme.ink)
                    Text("Automatically run Purge Memory when alert level reached")
                        .font(Theme.caption).foregroundStyle(Theme.mute)
                }
            }
            .toggleStyle(.switch)

            Picker("From level", selection: $config.autoPurgeAtLevel) {
                ForEach(AlertLevel.allCases, id: \.self) { Text($0.label).tag($0) }
            }
            .disabled(!config.autoPurgeEnabled)

            HStack {
                Button("Save") {
                    config.save()
                    coordinator.updateThresholds(config)
                    savedAt = Date()
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)

                if let s = savedAt, Date().timeIntervalSince(s) < 3 {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accent)
                        Text("Saved").font(Theme.caption).foregroundStyle(Theme.accent)
                    }
                }
                Spacer()
                Button("Reset to defaults") { config = .defaults }
                    .buttonStyle(.borderless)
                    .foregroundStyle(Theme.mute)
                    .font(Theme.caption)
            }
        }
        .vqCard(padding: 22)
    }
}
