import Foundation
import SwiftData
import Combine
import Shared

@MainActor
public final class SamplingCoordinator: ObservableObject {
    @Published public private(set) var latestMemory: MemoryReading?
    @Published public private(set) var latestProcesses: [ProcessReading] = []

    private let memoryService = MemoryService()
    private let processService = ProcessService()
    private let modelContext: ModelContext
    private let engine = ThresholdEngine(config: ThresholdConfig.load())

    private var memoryTimer: Timer?
    private var processTimer: Timer?
    private var lastAutoPurge: Date?

    public static let memoryInterval: TimeInterval = 2
    public static let processInterval: TimeInterval = 60
    public static let processTopN: Int = 30

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    public func updateThresholds(_ cfg: ThresholdConfig) {
        engine.config = cfg
        engine.reset()
    }

    public func start() {
        sampleMemory()
        sampleProcesses()
        memoryTimer = Timer.scheduledTimer(withTimeInterval: Self.memoryInterval, repeats: true) { _ in
            Task { @MainActor [weak self] in self?.sampleMemory() }
        }
        processTimer = Timer.scheduledTimer(withTimeInterval: Self.processInterval, repeats: true) { _ in
            Task { @MainActor [weak self] in self?.sampleProcesses() }
        }
    }

    public func stop() {
        memoryTimer?.invalidate()
        processTimer?.invalidate()
    }

    private func sampleMemory() {
        let reading = memoryService.readCurrent()
        latestMemory = reading
        modelContext.insert(MemorySnapshot(reading: reading))
        try? modelContext.save()

        if let level = engine.evaluate(reading) {
            handleAlert(level: level, reading: reading)
        }
    }

    private func sampleProcesses() {
        let top = processService.topByRSS(limit: Self.processTopN)
        latestProcesses = top
        let ts = Date()
        for r in top {
            modelContext.insert(ProcessSnapshot(reading: r, timestamp: ts))
        }
        try? modelContext.save()
    }

    private func handleAlert(level: AlertLevel, reading: MemoryReading) {
        let unusedGB = Double(reading.unusedBytes) / 1_073_741_824
        let trigger: String
        switch level {
        case .warning:
            trigger = String(format: "Unused < %.1f GB for %ds", engine.config.warningUnusedGB, engine.config.warningHoldSeconds)
        case .critical:
            trigger = String(format: "Unused < %.1f GB for %ds", engine.config.criticalUnusedGB, engine.config.criticalHoldSeconds)
        case .emergency:
            trigger = "Swap activity for \(engine.config.emergencyHoldSeconds)s"
        }

        let alert = AlertEvent(level: level, trigger: trigger)
        modelContext.insert(alert)
        try? modelContext.save()

        let body = String(format: "Unused: %.1f GB. %@", unusedGB, trigger)
        NotificationService.shared.deliver(level: level, message: body, identifier: alert.id.uuidString)

        if engine.config.autoPurgeEnabled,
           level.severity >= engine.config.autoPurgeAtLevel.severity {
            // Respect cooldown
            if let last = lastAutoPurge,
               Date().timeIntervalSince(last) < Double(engine.config.autoPurgeCooldownSeconds) {
                return
            }
            Task { await autoPurge() }
        }
    }

    private func autoPurge() async {
        do {
            let result = try await HelperBridge.shared.send(.purgeMemory)
            switch result {
            case .success:
                lastAutoPurge = Date()
                UserActionLog.shared.record(type: "auto_purge", success: true)
            case .denied(let r):
                UserActionLog.shared.record(type: "auto_purge", success: false, error: r)
            case .failed(let e):
                UserActionLog.shared.record(type: "auto_purge", success: false, error: e)
            }
        } catch {
            UserActionLog.shared.record(type: "auto_purge", success: false, error: error.localizedDescription)
        }
    }
}
