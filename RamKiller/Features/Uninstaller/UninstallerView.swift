import SwiftUI

struct UninstallerView: View {
    @State private var apps: [AppInfo] = []
    @State private var selection: AppInfo.ID?
    @State private var loading: Bool = true

    private var selectedApp: AppInfo? {
        apps.first { $0.id == selection }
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                AppDropZone { url in
                    Task {
                        let info = await Task.detached(priority: .userInitiated) {
                            AppDiscoveryService().appInfo(at: url)
                        }.value
                        guard let info else { return }
                        if !apps.contains(where: { $0.id == info.id }) {
                            apps.insert(info, at: 0)
                        }
                        selection = info.id
                    }
                }
                .padding(.horizontal, 8)
                .padding(.top, 8)
                AppListView(apps: apps, selection: $selection)
            }
            .frame(minWidth: 320, idealWidth: 360, maxWidth: 400)
            .frame(maxHeight: .infinity)

            Divider()

            Group {
                if let app = selectedApp {
                    AppDetailView(app: app).id(app.id)
                } else if loading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ContentUnavailableView("Select an app", systemImage: "app.dashed")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("Uninstaller")
        .task { await loadApps() }
    }

    private func loadApps() async {
        loading = true
        // Run on background thread to avoid blocking the main thread (each app scans its bundle for size)
        let result = await Task.detached(priority: .userInitiated) {
            AppDiscoveryService().discover()
        }.value
        apps = result
        loading = false
    }
}
