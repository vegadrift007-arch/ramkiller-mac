import SwiftUI

struct AutomationSettingsSection: View {
    @State private var config: ThresholdConfig = .load()
    @EnvironmentObject private var coordinator: SamplingCoordinator
    @State private var savedAt: Date?

    var body: some View {
        Section("Automation") {
            VStack(alignment: .leading) {
                Text("⚠️ Warning: Unused < \(config.warningUnusedGB, specifier: "%.1f") GB for \(config.warningHoldSeconds)s")
                    .font(.caption)
                Slider(value: $config.warningUnusedGB, in: 0.5...8.0, step: 0.5)
            }
            VStack(alignment: .leading) {
                Text("🔴 Critical: Unused < \(config.criticalUnusedGB, specifier: "%.1f") GB for \(config.criticalHoldSeconds)s")
                    .font(.caption)
                Slider(value: $config.criticalUnusedGB, in: 0.2...4.0, step: 0.1)
            }
            Toggle("Auto-purge on threshold", isOn: $config.autoPurgeEnabled)
            Picker("Trigger from level", selection: $config.autoPurgeAtLevel) {
                ForEach(AlertLevel.allCases, id: \.self) { Text($0.label).tag($0) }
            }
            .disabled(!config.autoPurgeEnabled)

            HStack {
                Button("Save") {
                    config.save()
                    coordinator.updateThresholds(config)
                    savedAt = Date()
                }
                if let s = savedAt, Date().timeIntervalSince(s) < 3 {
                    Text("Saved").font(.caption).foregroundStyle(.green)
                }
                Spacer()
                Button("Reset to defaults") {
                    config = .defaults
                }
            }
        }
    }
}
