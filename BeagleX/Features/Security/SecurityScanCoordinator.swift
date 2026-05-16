// BeagleX/Features/Security/SecurityScanCoordinator.swift
import Foundation
import Combine
import UserNotifications
import Shared

@MainActor
final class SecurityScanCoordinator: ObservableObject {
    @Published private(set) var scanState: ScanState = .idle
    @Published var findings: [SecurityFinding] = [] {
        didSet {
            // Filter out any already-ignored findings when set from outside (e.g., tests)
            let ignored = ignoredIDs
            if findings.contains(where: { ignored.contains($0.id.uuidString) }) {
                findings = findings.filter { !ignored.contains($0.id.uuidString) }
            }
        }
    }
    @Published private(set) var lastScanDate: Date?

    var autoScanInterval: String {
        get { UserDefaults.standard.string(forKey: "security.autoScanInterval") ?? "off" }
        set { UserDefaults.standard.set(newValue, forKey: "security.autoScanInterval") }
    }

    private var ignoredIDs: Set<String> {
        get {
            let raw = UserDefaults.standard.string(forKey: "security.ignoredIDs") ?? ""
            return Set(raw.components(separatedBy: ",").filter { !$0.isEmpty })
        }
        set {
            UserDefaults.standard.set(newValue.joined(separator: ","), forKey: "security.ignoredIDs")
        }
    }

    private let checks: [any SecurityCheck] = [
        MalwareSignatureCheck(),
        SuspiciousLaunchItemCheck(),
        NetworkConnectionCheck(),
        PermissionAbuseCheck(),
    ]

    init() {
        lastScanDate = UserDefaults.standard.object(forKey: "security.lastScanDate") as? Date
    }

    /// Call once on app start — triggers auto-scan if overdue.
    func start() {
        let interval = autoScanInterval
        guard interval != "off" else { return }
        let hours: Double = interval == "daily" ? 24 : 168
        guard let last = lastScanDate else { Task { await scan() }; return }
        if Date().timeIntervalSince(last) > hours * 3600 { Task { await scan() } }
    }

    func scan() async {
        guard scanState == .idle else { return }
        scanState = .scanning(progress: 0)

        // Run all checks with a 20-second per-check timeout so a hung subprocess
        // (e.g. lsof pipe deadlock) can't freeze the scan indefinitely.
        var all: [SecurityFinding] = []
        let total = Double(checks.count)
        for (i, check) in checks.enumerated() {
            scanState = .scanning(progress: Double(i) / total)
            let results = await withTimeout(seconds: 20) { await check.run() }
            all += results ?? []
        }
        scanState = .scanning(progress: 1)
        let ignored = ignoredIDs
        let filtered = all
            .filter { !ignored.contains($0.id.uuidString) }
            .sorted { $0.severity > $1.severity }

        let now = Date()
        findings = filtered
        lastScanDate = now
        UserDefaults.standard.set(now, forKey: "security.lastScanDate")
        scanState = .done(now)

        let serious = filtered.filter { $0.severity >= .warning }
        if !serious.isEmpty { deliverNotification(count: serious.count) }
    }

    func ignore(_ finding: SecurityFinding) {
        var ids = ignoredIDs
        ids.insert(finding.id.uuidString)
        ignoredIDs = ids
        findings.removeAll { $0.id == finding.id }
    }

    func remove(_ finding: SecurityFinding) async {
        guard let path = finding.path else { return }
        do {
            if path.hasPrefix("/Library/") {
                let cmd: HelperCommand = path.hasSuffix(".plist")
                    ? .deletePlist(path: path)
                    : .removeAppBundle(path: path)
                _ = try await HelperBridge.shared.send(cmd)
            } else {
                try FileManager.default.trashItem(at: URL(fileURLWithPath: path), resultingItemURL: nil)
            }
            findings.removeAll { $0.id == finding.id }
            UserActionLog.shared.record(type: "security_remove", target: path, success: true)
        } catch {
            UserActionLog.shared.record(type: "security_remove", target: path,
                                        success: false, error: error.localizedDescription)
        }
    }

    /// Runs `operation` and returns its result, or `nil` if it exceeds `seconds`.
    private func withTimeout<T: Sendable>(seconds: Double, operation: @escaping @Sendable () async -> T) async -> T? {
        await withTaskGroup(of: T?.self) { group in
            group.addTask { await operation() }
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                return nil
            }
            let result = await group.next() ?? nil
            group.cancelAll()
            return result
        }
    }

    private func deliverNotification(count: Int) {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "BeagleX — Security Alert")
        content.body = String(format: String(localized: "%d security issue(s) found"), count)
        content.sound = .default
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: "security-\(UUID())", content: content, trigger: nil)
        )
    }
}
