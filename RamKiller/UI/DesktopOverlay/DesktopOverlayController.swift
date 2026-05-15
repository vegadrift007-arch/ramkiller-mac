import AppKit
import SwiftUI
import Combine

/// Shows a live stats NSStatusItem in the system menu bar (CPU / RAM / network).
@MainActor
final class DesktopOverlayController: ObservableObject {
    static let shared = DesktopOverlayController()

    private static let defaultsKey = "desktopOverlayEnabled"

    @Published var isEnabled: Bool = UserDefaults.standard.bool(forKey: defaultsKey) {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: Self.defaultsKey)
            isEnabled ? showItem() : hideItem()
        }
    }

    private var statusItem: NSStatusItem?
    private var hostingView: NSHostingView<AnyView>?
    private weak var coordinator: SamplingCoordinator?
    private var cancellable: AnyCancellable?

    private init() {}

    func configure(coordinator: SamplingCoordinator) {
        self.coordinator = coordinator
        if isEnabled { showItem() }
    }

    // MARK: - Status item lifecycle

    private func showItem() {
        guard statusItem == nil, let coordinator else { return }

        let view = AnyView(
            MenuBarStatsView()
                .environmentObject(coordinator)
        )
        let hosting = NSHostingView(rootView: view)
        hosting.autoresizingMask = [.width, .height]

        // Measure intrinsic width for the status item length
        let w = hosting.fittingSize.width.isZero ? 220 : hosting.fittingSize.width

        let item = NSStatusBar.system.statusItem(withLength: w)
        item.isVisible = true

        if let button = item.button {
            hosting.frame = button.bounds
            button.addSubview(hosting)
            button.autoresizesSubviews = true
            button.action = #selector(AppDelegate.openMainWindow)
            button.target = NSApp.delegate
        }

        // Resize the status item whenever the coordinator publishes new values
        cancellable = coordinator.objectWillChange.sink { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.resizeItem()
            }
        }

        statusItem = item
        hostingView = hosting
    }

    private func hideItem() {
        cancellable = nil
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
        }
        statusItem = nil
        hostingView = nil
    }

    private func resizeItem() {
        guard let hosting = hostingView, let item = statusItem else { return }
        let w = hosting.fittingSize.width
        if w > 0 { item.length = w }
    }
}
