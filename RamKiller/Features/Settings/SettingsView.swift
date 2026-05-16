import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @AppStorage("launchAtLogin") private var launchAtLogin: Bool = true
    @State private var registrationError: String?
    @ObservedObject private var helperManager = HelperManager.shared
    @State private var helperError: String?
    @State private var helperVersion: String = "?"
    @EnvironmentObject private var securityCoordinator: SecurityScanCoordinator

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                section("Startup") {
                    Toggle(isOn: $launchAtLogin) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Launch at login").foregroundStyle(Theme.ink)
                            Text("Status: \(loginStatusLabel)").font(Theme.caption).foregroundStyle(Theme.mute)
                        }
                    }
                    .toggleStyle(.switch)
                    .onChange(of: launchAtLogin) { _, newValue in
                        applyLoginSetting(enabled: newValue)
                    }
                    if let err = registrationError {
                        Text(err).font(Theme.caption).foregroundStyle(Theme.danger)
                    }
                }

                section("Privileged Helper") {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Circle().fill(helperBadgeColor).frame(width: 8, height: 8)
                                Text(helperStatusLabel).font(Theme.bodyText).foregroundStyle(Theme.ink)
                            }
                            Text("Required for: Purge Memory, killing system processes, managing system launch items")
                                .font(Theme.caption).foregroundStyle(Theme.mute)
                        }
                        Spacer()
                        Text("v\(helperVersion)").font(Theme.mono(11)).foregroundStyle(Theme.mute)
                    }

                    HStack {
                        Button("Install / Repair") { installHelper() }
                            .buttonStyle(.borderedProminent)
                            .tint(Theme.accent)
                        Button("Restart") { restartHelper() }
                            .disabled(helperManager.status == .notRegistered)
                        Button("Uninstall") { uninstallHelper() }
                            .disabled(helperManager.status == .notRegistered)
                        if helperManager.status == .requiresApproval {
                            Button("Open System Settings") {
                                SMAppService.openSystemSettingsLoginItems()
                            }
                            .foregroundStyle(Theme.warn)
                        }
                    }
                    if let e = helperError {
                        Text(e).font(Theme.caption).foregroundStyle(Theme.danger)
                    }
                }

                DesktopOverlaySection()

                ThemePickerSection()

                LanguagePickerSection()

                AutomationSettingsSection()

                section("Security") {
                    Picker(String(localized: "Auto-scan interval"),
                           selection: Binding(
                               get: { securityCoordinator.autoScanInterval },
                               set: { securityCoordinator.autoScanInterval = $0 }
                           )) {
                        Text(String(localized: "Off")).tag("off")
                        Text(String(localized: "Daily")).tag("daily")
                        Text(String(localized: "Weekly")).tag("weekly")
                    }
                    .pickerStyle(.segmented)
                }

                section("About") {
                    HStack { Text("Version").vqEyebrow(); Spacer(); Text(appVersion).font(Theme.mono(12)).foregroundStyle(Theme.ink) }
                    HStack { Text("Bundle ID").vqEyebrow(); Spacer(); Text("com.vannaq.RamKiller").font(Theme.mono(11)).foregroundStyle(Theme.inkSoft) }
                }
            }
            .padding(24)
            .frame(maxWidth: 720)
        }
        .background(Theme.bg)
        .toolbarBackground(Theme.bg, for: .windowToolbar)
        .toolbarBackground(.visible, for: .windowToolbar)
        .navigationTitle("Settings")
        .onAppear {
            if launchAtLogin && LoginItemService.shared.status != .enabled {
                applyLoginSetting(enabled: true)
            }
            helperManager.refresh()
        }
        .task { await loadHelperVersion() }
    }

    private func section<Content: View>(_ title: LocalizedStringKey, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).vqEyebrow()
            content()
        }
        .vqCard(padding: 22)
    }

    private var loginStatusLabel: String {
        switch LoginItemService.shared.status {
        case .enabled:           return String(localized: "Enabled")
        case .notRegistered:     return String(localized: "Not registered")
        case .requiresApproval:  return String(localized: "Requires approval (System Settings)")
        case .notFound:          return String(localized: "Not found")
        @unknown default:        return String(localized: "Unknown")
        }
    }

    private var helperStatusLabel: String {
        switch helperManager.status {
        case .enabled:           return String(localized: "Helper enabled")
        case .requiresApproval:  return String(localized: "Needs approval — open System Settings")
        case .notRegistered:     return String(localized: "Not installed")
        case .unknown:           return String(localized: "Unknown")
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    private var helperBadgeColor: Color {
        switch helperManager.status {
        case .enabled:           return Theme.accent
        case .requiresApproval:  return Theme.warn
        case .notRegistered:     return Theme.danger
        case .unknown:           return Theme.mute
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

    private func restartHelper() {
        Task {
            helperError = await helperManager.restart()
            if helperError == nil {
                await loadHelperVersion()
            }
        }
    }

    private func loadHelperVersion() async {
        if let v = await HelperBridge.shared.helperVersion() {
            helperVersion = v
        } else {
            helperVersion = "—"
        }
    }
}
