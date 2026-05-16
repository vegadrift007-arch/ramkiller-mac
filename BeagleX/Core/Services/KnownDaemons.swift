import Foundation

public enum KnownDaemons {
    /// Labels that should ALWAYS be displayed as "do not touch — system critical".
    public static let critical: Set<String> = [
        "com.apple.cfprefsd.xpc.daemon",
        "com.apple.cfprefsd.xpc.agent",
        "com.apple.distnoted.xpc.daemon",
        "com.apple.distnoted.xpc.agent",
        "com.apple.tccd",
        "com.apple.WindowServer",
        "com.apple.coreservicesd",
        "com.apple.launchd",
        "com.apple.notifyd",
        "com.apple.audio.coreaudiod",
        "com.apple.opendirectoryd",
        "com.apple.securityd",
        "com.apple.trustd",
        "com.apple.spotlight",
        "com.apple.mds",
        "com.apple.metadata.mds"
    ]

    public static func isCritical(_ label: String) -> Bool {
        critical.contains(label)
    }

    public static func isApple(_ label: String) -> Bool {
        label.hasPrefix("com.apple.")
    }
}
