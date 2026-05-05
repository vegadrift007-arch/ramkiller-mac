import Foundation

public enum HelperCommand: Codable, Equatable, Sendable {
    case purgeMemory
    case killProcess(pid: Int32, signal: Int32)
    case unloadLaunchPlist(path: String)            // launchctl bootout
    case loadLaunchPlist(path: String)              // launchctl bootstrap
    case renamePlist(from: String, to: String)      // for .disabled toggling
    case deletePlist(path: String)                  // permanent delete
    /// Remove an .app bundle owned by root (MDM/admin-installed apps).
    case removeAppBundle(path: String)
    /// Forget a pkgutil receipt. Helper validates ID format (reverse-DNS, no path chars).
    case forgetPkgReceipt(id: String)
}
