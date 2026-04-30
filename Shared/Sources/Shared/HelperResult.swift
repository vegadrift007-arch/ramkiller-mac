import Foundation

public enum HelperResult: Codable, Equatable, Sendable {
    case success
    case denied(reason: String)
    case failed(error: String)
}
