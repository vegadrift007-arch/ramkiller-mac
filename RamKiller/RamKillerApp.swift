import SwiftUI
import SwiftData

@main
struct RamKillerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let container: ModelContainer
    @StateObject private var samplingCoordinator: SamplingCoordinator

    init() {
        let schema = Schema([
            MemorySnapshot.self,
            ProcessSnapshot.self,
            AlertEvent.self,
            UserAction.self
        ])
        let url = URL.applicationSupportDirectory.appending(path: "RamKiller/db.store")
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let config = ModelConfiguration(schema: schema, url: url)
        let container = try! ModelContainer(for: schema, configurations: [config])
        self.container = container
        SharedContainer.container = container
        self._samplingCoordinator = StateObject(wrappedValue: SamplingCoordinator(modelContext: ModelContext(container)))
    }

    var body: some Scene {
        Window("RamKiller", id: "main") {
            MainContentView()
                .frame(minWidth: 900, minHeight: 600)
                .environmentObject(samplingCoordinator)
                .environmentObject(ThemeManager.shared)
                .onAppear { samplingCoordinator.start() }
        }
        .modelContainer(container)
        .windowToolbarStyle(.unified)

        MenuBarExtra {
            MenuBarView()
                .environmentObject(samplingCoordinator)
                .environmentObject(ThemeManager.shared)
        } label: {
            MenuBarIcon()
                .environmentObject(samplingCoordinator)
                .environmentObject(ThemeManager.shared)
        }
        .menuBarExtraStyle(.window)
    }
}
