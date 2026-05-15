import Foundation
import SwiftData
import Combine
import Shared

@MainActor
public final class SamplingCoordinator: ObservableObject {
    @Published public private(set) var latestMemory: MemoryReading?
    @Published public private(set) var latestProcesses: [ProcessReading] = []
    @Published public private(set) var cpuPercent: Double = 0
    @Published public private(set) var networkDown: Double = 0
    @Published public private(set) var networkUp: Double = 0

    private let memoryService = MemoryService()
    private let processService = ProcessService()
    private let cpuService = CPUService()
    private let networkService = NetworkService()
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
        Task { await sampleProcesses() }
        memoryTimer = Timer.scheduledTimer(withTimeInterval: Self.memoryInterval, repeats: true) { _ in
            Task { @MainActor [weak self] in self?.sampleMemory() }
        }
        processTimer = Timer.scheduledTimer(withTimeInterval: Self.processInterval, repeats: true) { _ in
            Task { [weak self] in await self?.sampleProcesses() }
        }
    }

    public func stop() {
        memoryTimer?.invalidate()
        processTimer?.invalidate()
    }

    /// vm_statistics64 + CPU + network are fast syscalls — fine to keep on main.
    private func sampleMemory() {
        let reading = memoryService.readCurrent()
        latestMemory = reading
        cpuPercent = cpuService.cpuUsage()
        let net = networkService.readCurrent()
        networkDown = net.downBytesPerSec
        networkUp   = net.upBytesPerSec
        modelContext.insert(MemorySnapshot(reading: reading))
        try? modelContext.save()

        if let level = engine.evaluate(reading) {
            handleAlert(level: level, reading: reading)
        }
    }

    /// Process sampling enumerates 800+ procs via sysctl + proc_pidinfo — 1-3s on main thread
    /// would freeze UI. Run the gather on a detached task, hop back to main only for state assign.
    nonisolated private func sampleProcesses() async {
        let top = await Task.detached(priority: .utility) { [processService] in
            processService.topByRSS(limit: Self.processTopN)
        }.value

        await MainActor.run { [weak self] in
            guard let self else { return }
            self.latestProcesses = top
            let ts = Date()
            for r in top {
                self.modelContext.insert(ProcessSnapshot(reading: r, timestamp: ts))
            }
            try? self.modelContext.save()
        }
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
            if let last = lastAutoPurge,
               Date().timeIntervalSince(last) < Double(engine.config.autoPurgeCooldownSeconds) {
                return
            }
            Task { await autoPurge() }
        }
    }

    private func autoPurge() async {
        if case .success? = await HelperBridge.shared.sendAndLog(.purgeMemory, type: "auto_purge") {
            lastAutoPurge = Date()
        }
    }
}
