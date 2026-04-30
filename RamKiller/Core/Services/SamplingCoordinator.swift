import Foundation
import SwiftData
import Combine

@MainActor
public final class SamplingCoordinator: ObservableObject {
    @Published public private(set) var latestMemory: MemoryReading?
    @Published public private(set) var latestProcesses: [ProcessReading] = []

    private let memoryService = MemoryService()
    private let processService = ProcessService()
    private let modelContext: ModelContext

    private var memoryTimer: Timer?
    private var processTimer: Timer?

    public static let memoryInterval: TimeInterval = 2
    public static let processInterval: TimeInterval = 60
    public static let processTopN: Int = 30

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    public func start() {
        sampleMemory()       // immediate first read
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
        memoryTimer = nil
        processTimer = nil
    }

    private func sampleMemory() {
        let reading = memoryService.readCurrent()
        latestMemory = reading
        modelContext.insert(MemorySnapshot(reading: reading))
        try? modelContext.save()
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
}
