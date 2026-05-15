import SwiftUI

struct MainContentView: View {
    @State private var selection: SidebarItem? = .monitoring
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "memorychip.fill")
                        .foregroundStyle(Theme.accent)
                        .font(.title2)
                    Text("RamKiller")
                        .font(Theme.display(18))
                        .foregroundStyle(Theme.ink)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 8)

                SidebarView(selection: $selection)
            }
            .background(Theme.bg2)
        } detail: {
            detailView
                .background(Theme.bg)
        }
        .preferredColorScheme(themeManager.current.palette.isLight ? .light : .dark)
        // re-key the entire view tree when theme changes so all static Theme.* reads pick up new palette
        .id(themeManager.current.rawValue)
    }

    @ViewBuilder
    private var detailView: some View {
        switch selection {
        case .monitoring:    MonitoringView()
        case .processes:     ProcessesView()
        case .automation:    AutomationView()
        case .security:      SecurityView()
        case .cacheCleaner:  CacheCleanerView()
        case .largeFiles:    LargeFilesView()
        case .uninstaller:   UninstallerView()
        case .launchItems:   LaunchItemsView()
        case .settings:      SettingsView()
        case nil:            PlaceholderView(title: "Pick a tool", phase: "—", icon: "sidebar.left")
        }
    }
}
