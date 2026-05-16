import Foundation

public enum SystemAppBlacklist {
    public static let bundleIDs: Set<String> = [
        "com.apple.finder",
        "com.apple.Safari",
        "com.apple.mail",
        "com.apple.systempreferences",
        "com.apple.Settings",
        "com.apple.dock",
        "com.apple.AppStore"
    ]

    public static func isProtected(_ app: AppInfo) -> Bool {
        if bundleIDs.contains(app.bundleIdentifier) { return true }
        // Anything inside /System/ or /Library/Apple/ is OS-bundled
        return app.path.hasPrefix("/System/") || app.path.hasPrefix("/Library/Apple/")
    }
}
