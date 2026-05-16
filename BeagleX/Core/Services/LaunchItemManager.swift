import Foundation
import Shared

@MainActor
public final class LaunchItemManager {
    public static let shared = LaunchItemManager()
    private init() {}

    public func disable(_ item: LaunchItem) async throws {
        guard let plist = item.plistPath else { return }
        let disabled = plist + ".disabled"
        switch item.source {
        case .userLaunchAgent:
            // User dirs: do it ourselves
            unloadUserAgent(plist: plist)
            try FileManager.default.moveItem(atPath: plist, toPath: disabled)
        case .systemLaunchAgent, .systemLaunchDaemon:
            _ = try await HelperBridge.shared.send(.unloadLaunchPlist(path: plist))
            _ = try await HelperBridge.shared.send(.renamePlist(from: plist, to: disabled))
        case .loginItem:
            try LoginItemService.shared.unregister().get()
        }
        UserActionLog.shared.record(type: "disable_launch_item", target: item.label, success: true)
    }

    public func enable(_ item: LaunchItem) async throws {
        guard let plist = item.plistPath else { return }
        let active = plist.hasSuffix(".disabled") ? String(plist.dropLast(".disabled".count)) : plist
        switch item.source {
        case .userLaunchAgent:
            try FileManager.default.moveItem(atPath: plist, toPath: active)
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/bin/launchctl")
            task.arguments = ["bootstrap", "gui/\(getuid())", active]
            try? task.run()
        case .systemLaunchAgent, .systemLaunchDaemon:
            _ = try await HelperBridge.shared.send(.renamePlist(from: plist, to: active))
            _ = try await HelperBridge.shared.send(.loadLaunchPlist(path: active))
        case .loginItem:
            try LoginItemService.shared.register().get()
        }
        UserActionLog.shared.record(type: "enable_launch_item", target: item.label, success: true)
    }

    public func delete(_ item: LaunchItem) async throws {
        guard let plist = item.plistPath else { return }
        switch item.source {
        case .userLaunchAgent:
            try FileManager.default.removeItem(atPath: plist)
        case .systemLaunchAgent, .systemLaunchDaemon:
            _ = try await HelperBridge.shared.send(.deletePlist(path: plist))
        case .loginItem:
            try LoginItemService.shared.unregister().get()
        }
        UserActionLog.shared.record(type: "delete_launch_item", target: item.label, success: true)
    }

    private func unloadUserAgent(plist: String) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        task.arguments = ["bootout", "gui/\(getuid())", plist]
        try? task.run()
        task.waitUntilExit()
    }
}

// Note: Swift stdlib's Result already has a `.get()` method that does exactly this.
// Previously we had a duplicate extension here that shadowed it — removed.
