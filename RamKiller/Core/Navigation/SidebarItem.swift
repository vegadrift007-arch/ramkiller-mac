import Foundation

enum SidebarItem: String, CaseIterable, Identifiable, Hashable {
    case monitoring
    case processes
    case automation
    case security
    case cacheCleaner
    case largeFiles
    case uninstaller
    case launchItems
    case settings

    var id: String { rawValue }

    var label: String {
        switch self {
        case .monitoring:   return String(localized: "Memory")
        case .processes:    return String(localized: "Processes")
        case .automation:   return String(localized: "Automation")
        case .security:     return String(localized: "Security")
        case .cacheCleaner: return String(localized: "Cache Cleaner")
        case .largeFiles:   return String(localized: "Large Files")
        case .uninstaller:  return String(localized: "Uninstaller")
        case .launchItems:  return String(localized: "Launch Items")
        case .settings:     return String(localized: "Settings")
        }
    }

    var icon: String {
        switch self {
        case .monitoring:   return "memorychip"
        case .processes:    return "list.bullet.rectangle"
        case .automation:   return "wand.and.stars"
        case .security:     return "shield.checkerboard"
        case .cacheCleaner: return "trash"
        case .largeFiles:   return "doc.zipper"
        case .uninstaller:  return "shippingbox"
        case .launchItems:  return "powerplug"
        case .settings:     return "gearshape"
        }
    }
}
