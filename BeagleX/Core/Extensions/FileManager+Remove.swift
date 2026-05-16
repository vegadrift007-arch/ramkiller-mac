import Foundation

public extension FileManager {
    /// Removes a URL — either to Trash (recoverable) or permanently.
    /// Centralizes the awkward `trashItem(at:resultingItemURL:)` boilerplate.
    func remove(_ url: URL, toTrash: Bool) throws {
        if toTrash {
            var resulting: NSURL?
            try trashItem(at: url, resultingItemURL: &resulting)
        } else {
            try removeItem(at: url)
        }
    }
}
