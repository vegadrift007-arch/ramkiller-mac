import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @AppStorage("launchAtLogin") private var launchAtLogin: Bool = true
    @State private var registrationError: String?
    @ObservedObject private var helperManager = HelperManager.shared
    @State private var helperError: String?
    @State private var helperVersion: String = "?"

    var body: some View {
        Form {
            Section("Startup") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        applyLoginSetting(enabled: newValue)
                    }
                if let err = registrationError {
                    Text(err).font(.caption).foregroundStyle(.red)
                }
                Text("Status: \(loginStatusLabel)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Privileged Helper") {
                HStack {
                    HelperStatusBadge()
                    Spacer()
                    Text("v\(helperVersion)").font(.caption).foregroundStyle(.secondary)
                }
                HStack {
                    Button("Install / Repair") { installHelper() }
                    Button("Uninstall") { uninstallHelper() }
                        .disabled(helperManager.status == .notRegistered)
                    if helperManager.status == .requiresApproval {
                        Button("Open System Settings") {
                            SMAppService.openSystemSettingsLoginItems()
                        }
                    }
                }
                if let e = helperError {
                    Text(e).font(.caption).foregroundStyle(.red)
                }
                Text("Required for: Purge Memory, killing system processes")
                    .font(.caption2)
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
            helperManager.refresh()
        }
        .task { await loadHelperVersion() }
    }

    private var loginStatusLabel: String {
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

    private func installHelper() {
        helperError = helperManager.install()
        if helperError == nil {
            Task { await loadHelperVersion() }
        }
    }

    private func uninstallHelper() {
        helperError = helperManager.uninstall()
    }

    private func loadHelperVersion() async {
        if let v = await HelperBridge.shared.helperVersion() {
            helperVersion = v
        } else {
            helperVersion = "—"
        }
    }
}
