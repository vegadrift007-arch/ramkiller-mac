import SwiftUI

struct MainContentView: View {
    @State private var selection: SidebarItem? = .monitoring

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selection)
        } detail: {
            detailView
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch selection {
        case .monitoring:    MonitoringView()
        case .processes:     ProcessesView()
        case .automation:    AutomationView()
        case .cacheCleaner:  CacheCleanerView()
        case .largeFiles:    LargeFilesView()
        case .uninstaller:   UninstallerView()
        case .launchItems:   LaunchItemsView()
        case .settings:      SettingsView()
        case nil:            PlaceholderView(title: "Pick a tool", phase: "—", icon: "sidebar.left")
        }
    }
}

#Preview {
    MainContentView()
        .frame(width: 900, height: 600)
}
