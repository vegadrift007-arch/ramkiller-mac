import SwiftUI

struct LaunchItemsView: View {
    @State private var items: [LaunchItem] = []
    @State private var loading = true
    @State private var search: String = ""
    @State private var error: String?

    private var grouped: [(LaunchItem.Source, [LaunchItem])] {
        let sources: [LaunchItem.Source] = [.loginItem, .userLaunchAgent, .systemLaunchAgent, .systemLaunchDaemon]
        return sources.compactMap { src in
            let inGroup = items.filter { $0.source == src && (search.isEmpty || $0.label.localizedCaseInsensitiveContains(search)) }
            return inGroup.isEmpty ? nil : (src, inGroup)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top bar
            HStack {
                TextField("Search labels", text: $search)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 280)
                Button("Refresh") { Task { await load() } }
                Spacer()
                Text("\(items.count) total")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            if loading {
                ProgressView().padding()
                Spacer()
            } else if items.isEmpty {
                ContentUnavailableView("No launch items found", systemImage: "powerplug")
                    .frame(maxHeight: .infinity)
            } else {
                List {
                    ForEach(grouped, id: \.0) { (src, list) in
                        Section(src.label) {
                            ForEach(list) { item in
                                LaunchItemRow(
                                    item: item,
                                    onDisable: { Task { await act(item, action: .disable) } },
                                    onEnable: { Task { await act(item, action: .enable) } },
                                    onDelete: { Task { await act(item, action: .delete) } }
                                )
                            }
                        }
                    }
                }
            }

            if let e = error {
                Text(e).font(.caption).foregroundStyle(.red).padding()
            }
        }
        .navigationTitle("Launch Items")
        .toolbarBackground(Theme.bg, for: .windowToolbar)
        .toolbarBackground(.visible, for: .windowToolbar)
        .task { await load() }
    }

    private enum Action { case disable, enable, delete }

    private func load() async {
        loading = true
        items = await PlistService().discover()
        loading = false
    }

    private func act(_ item: LaunchItem, action: Action) async {
        do {
            switch action {
            case .disable: try await LaunchItemManager.shared.disable(item)
            case .enable:  try await LaunchItemManager.shared.enable(item)
            case .delete:  try await LaunchItemManager.shared.delete(item)
            }
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
        await load()
    }
}
