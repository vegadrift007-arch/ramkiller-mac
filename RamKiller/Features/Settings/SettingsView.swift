import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @AppStorage("launchAtLogin") private var launchAtLogin: Bool = true
    @State private var registrationError: String?

    var body: some View {
        Form {
            Section("Startup") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        applyLoginSetting(enabled: newValue)
                    }
                if let err = registrationError {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                Text("Status: \(statusLabel)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("About") {
                LabeledContent("Version", value: "0.1.0")
                LabeledContent("Bundle ID", value: "com.vannaq.RamKiller")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        .onAppear {
            if launchAtLogin && LoginItemService.shared.status != .enabled {
                applyLoginSetting(enabled: true)
            }
        }
    }

    private var statusLabel: String {
        switch LoginItemService.shared.status {
        case .enabled:           return "Enabled"
        case .notRegistered:     return "Not registered"
        case .requiresApproval:  return "Requires approval (System Settings → Login Items)"
        case .notFound:          return "Not found"
        @unknown default:        return "Unknown"
        }
    }

    private func applyLoginSetting(enabled: Bool) {
        let result = enabled
            ? LoginItemService.shared.register()
            : LoginItemService.shared.unregister()
        if case .failure(let err) = result {
            registrationError = err.localizedDescription
        } else {
            registrationError = nil
        }
    }
}
