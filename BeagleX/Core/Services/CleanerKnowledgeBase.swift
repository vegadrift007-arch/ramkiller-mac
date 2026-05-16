import Foundation

public final class CleanerKnowledgeBase {
    public static let shared = CleanerKnowledgeBase()

    public let cleaners: [Cleaner]

    private init() {
        guard let url = Bundle.main.url(forResource: "cleaners", withExtension: "json", subdirectory: "KnowledgeBase")
                     ?? Bundle.main.url(forResource: "cleaners", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([Cleaner].self, from: data) else {
            NSLog("[cleaners] failed to load cleaners.json from bundle")
            self.cleaners = []
            return
        }
        self.cleaners = decoded
        NSLog("[cleaners] loaded \(decoded.count) cleaner definitions")
    }

    public func byCategory() -> [(CleanerCategory, [Cleaner])] {
        CleanerCategory.allCases.compactMap { cat in
            let items = cleaners.filter { $0.category == cat }
            return items.isEmpty ? nil : (cat, items)
        }
    }
}
