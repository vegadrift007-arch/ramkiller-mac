import Foundation

public struct ThresholdConfig: Codable, Equatable {
    public var warningUnusedGB: Double = 2.0
    public var warningHoldSeconds: Int = 60

    public var criticalUnusedGB: Double = 0.8
    public var criticalHoldSeconds: Int = 30

    public var emergencyHoldSeconds: Int = 10  // triggers when swap activity > 0

    public var autoPurgeEnabled: Bool = false
    public var autoPurgeAtLevel: AlertLevel = .critical
    public var autoPurgeCooldownSeconds: Int = 300

    public static let defaults = ThresholdConfig()
}

extension ThresholdConfig {
    static let userDefaultsKey = "automation.thresholds"

    static func load() -> ThresholdConfig {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let cfg = try? JSONDecoder().decode(ThresholdConfig.self, from: data)
        else { return .defaults }
        return cfg
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.userDefaultsKey)
        }
    }
}
