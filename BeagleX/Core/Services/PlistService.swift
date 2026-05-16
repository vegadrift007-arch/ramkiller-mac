import Foundation
import ServiceManagement

public actor PlistService {
    public init() {}

    public func discover() async -> [LaunchItem] {
        var out: [LaunchItem] = []
        out.append(contentsOf: scanDirectory(
            path: NSString(string: "~/Library/LaunchAgents").expandingTildeInPath,
            source: .userLaunchAgent
        ))
        out.append(contentsOf: scanDirectory(
            path: "/Library/LaunchAgents",
            source: .systemLaunchAgent
        ))
        out.append(contentsOf: scanDirectory(
            path: "/Library/LaunchDaemons",
            source: .systemLaunchDaemon
        ))
        out.append(await readOwnLoginItem())
        return out.sorted { $0.label.lowercased() < $1.label.lowercased() }
    }

    private func scanDirectory(path: String, source: LaunchItem.Source) -> [LaunchItem] {
        var items: [LaunchItem] = []
        guard let entries = try? FileManager.default.contentsOfDirectory(atPath: path) else { return [] }
        for name in entries where name.hasSuffix(".plist") || name.hasSuffix(".plist.disabled") {
            let full = "\(path)/\(name)"
            let isDisabled = name.hasSuffix(".disabled")
            let actualPlist = isDisabled ? String(full.dropLast(".disabled".count)) : full
            // For .disabled files we read the renamed file directly
            let plistToRead = isDisabled ? full : actualPlist
            guard let dict = try? loadPlist(at: plistToRead) else { continue }
            let label = (dict["Label"] as? String)
                ?? (name as NSString).deletingPathExtension
            let program = (dict["Program"] as? String)
                ?? (dict["BundleProgram"] as? String)
                ?? (dict["ProgramArguments"] as? [String])?.first
            let bundleId = label.split(separator: ".").prefix(3).joined(separator: ".")
            items.append(LaunchItem(
                id: label, label: label, source: source,
                plistPath: full, program: program,
                isDisabled: isDisabled,
                isApple: KnownDaemons.isApple(label),
                bundleIdentifier: bundleId
            ))
        }
        return items
    }

    private func loadPlist(at path: String) throws -> [String: Any]? {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        return try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
    }

    private func readOwnLoginItem() async -> LaunchItem {
        let svc = SMAppService.mainApp
        return LaunchItem(
            id: "com.vannaq.BeagleX",
            label: "BeagleX",
            source: .loginItem,
            plistPath: nil,
            program: Bundle.main.executablePath,
            isDisabled: svc.status != .enabled,
            isApple: false,
            bundleIdentifier: "com.vannaq.BeagleX"
        )
    }
}
