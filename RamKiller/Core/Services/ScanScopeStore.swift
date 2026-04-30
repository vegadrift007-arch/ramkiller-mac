import Foundation
import Combine

public final class ScanScopeStore: ObservableObject {
    public static let shared = ScanScopeStore()

    private let key = "scan.folders"
    @Published public var folders: [URL] {
        didSet { save() }
    }

    private init() {
        if let stored = UserDefaults.standard.array(forKey: key) as? [String], !stored.isEmpty {
            self.folders = stored.map { URL(fileURLWithPath: $0) }
        } else {
            self.folders = ScanScopeStore.defaultFolders
        }
    }

    public static var defaultFolders: [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return ["Downloads", "Documents", "Movies", "Desktop"].map { home.appending(path: $0) }
    }

    public func add(_ url: URL) {
        guard !folders.contains(url) else { return }
        folders.append(url)
    }

    public func remove(_ url: URL) {
        folders.removeAll { $0 == url }
    }

    public func reset() {
        folders = Self.defaultFolders
    }

    private func save() {
        UserDefaults.standard.set(folders.map { $0.path }, forKey: key)
    }
}
