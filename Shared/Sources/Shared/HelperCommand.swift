import Foundation

public enum HelperCommand: Codable, Equatable, Sendable {
    case purgeMemory
    case killProcess(pid: Int32, signal: Int32)
}
