# Phase 1 — Memory Monitoring Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Live RAM monitoring that fully replaces the user's `vm_stat` + `top` command-line workflow. Includes a dynamic menubar percentage, a main-window dashboard with stat cards + charts, and a Top-30 process list with detail panel. Read-only — no kill / purge / clean (those land in Phase 2).

**Architecture:** Two services (`MemoryService`, `ProcessService`) sample at 2 s and 60 s respectively, write into SwiftData. UI observes the latest snapshot via `@Query`. A `RetentionService` prunes records older than 24 h once an hour.

**Tech Stack:** SwiftData, Swift Charts, Mach kernel APIs (`host_statistics64`, `mach_host_self`, `vm_pressure_monitor`), `proc_listpids` / `proc_pidinfo` (libproc).

**Prerequisite:** Phase 0 complete and on `main`.

---

## File Structure (created/modified in this Phase)

| Path | Purpose |
|---|---|
| `RamKiller/Core/Models/MemorySnapshot.swift` | SwiftData model for 2 s memory samples |
| `RamKiller/Core/Models/ProcessSnapshot.swift` | SwiftData model for 60 s process samples |
| `RamKiller/Core/Services/MemoryService.swift` | Wraps `host_statistics64` + vm_stat math |
| `RamKiller/Core/Services/ProcessService.swift` | Wraps `proc_listpids` + `proc_pidinfo` |
| `RamKiller/Core/Services/SamplingCoordinator.swift` | Owns the timers, persists snapshots |
| `RamKiller/Core/Services/RetentionService.swift` | Hourly pruning of 24 h+ old rows |
| `RamKiller/Core/Models/MemoryReading.swift` | In-memory struct (not persisted) — current snapshot |
| `RamKiller/Core/Models/ProcessReading.swift` | In-memory struct for one process |
| `RamKiller/UI/MenuBar/MenuBarView.swift` | (modify) live stats + Top 5 |
| `RamKiller/UI/MenuBar/MenuBarIcon.swift` | Dynamic % rendered to `NSImage` |
| `RamKiller/Features/Monitoring/MonitoringView.swift` | (replace) dashboard |
| `RamKiller/Features/Monitoring/StatCard.swift` | One Used/Unused/Compressor/Pressure card |
| `RamKiller/Features/Monitoring/MemoryAreaChart.swift` | Stacked area chart 1 h / 24 h |
| `RamKiller/Features/Monitoring/PressureTimelineChart.swift` | Colored timeline of pressure level |
| `RamKiller/Features/Monitoring/SwapRateChart.swift` | Line chart of swap in/out per second |
| `RamKiller/Features/Monitoring/AdvancedBreakdownView.swift` | Wired/Active/Inactive/Speculative |
| `RamKiller/Features/Processes/ProcessesView.swift` | (replace) Top 30 list + search |
| `RamKiller/Features/Processes/ProcessDetailView.swift` | Right-side detail panel |
| `RamKiller/Features/Processes/ProcessRow.swift` | One row in the list |
| `RamKiller/App/RamKillerApp.swift` | (modify) install ModelContainer + start sampling |
| `RamKillerTests/MemoryServiceTests.swift` | Unit tests |
| `RamKillerTests/ProcessServiceTests.swift` | Unit tests |
| `RamKillerTests/RetentionServiceTests.swift` | Unit tests |

---

## Task 1: `MemoryReading` value type

**Files:**
- Create: `/Users/a77/RamKiller/RamKiller/Core/Models/MemoryReading.swift`

- [ ] **Step 1: Write the file**

```swift
import Foundation

/// One in-memory snapshot of macOS memory state. Not persisted — the persisted form is `MemorySnapshot`.
public struct MemoryReading: Sendable, Equatable {
    public let timestamp: Date

    /// All values in bytes.
    public let totalBytes: Int64
    public let usedBytes: Int64
    public let unusedBytes: Int64
    public let wiredBytes: Int64
    public let activeBytes: Int64
    public let inactiveBytes: Int64
    public let speculativeBytes: Int64
    public let compressorBytes: Int64
    public let purgeableBytes: Int64
    public let externalBytes: Int64
    public let fileBackedBytes: Int64

    /// Per-second rate from kernel page counters (compared against last reading).
    public let swapInPagesPerSec: Double
    public let swapOutPagesPerSec: Double

    /// 0 = green, 1 = yellow, 2 = red. Read from `kern.memorystatus_vm_pressure_level`.
    public let pressureLevel: Int

    public var usedPercent: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(usedBytes) / Double(totalBytes) * 100
    }
}
```

- [ ] **Step 2: Verify it compiles**

⌘B. Expected: Build Succeeded.

- [ ] **Step 3: Commit**

```bash
git add RamKiller/Core/Models/MemoryReading.swift
git commit -m "phase-1: add MemoryReading struct"
```

---

## Task 2: `MemoryService` — read host_statistics64

**Files:**
- Create: `/Users/a77/RamKiller/RamKiller/Core/Services/MemoryService.swift`
- Test: `/Users/a77/RamKiller/RamKillerTests/MemoryServiceTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import RamKiller

final class MemoryServiceTests: XCTestCase {
    func testReadCurrentReturnsPlausibleValues() {
        let service = MemoryService()
        let reading = service.readCurrent()

        // Total memory > 1 GB on any modern Mac
        XCTAssertGreaterThan(reading.totalBytes, 1_000_000_000)
        // Used + Unused should approximately equal Total (within 5% to account for compressor/purgeable accounting)
        let approxTotal = reading.usedBytes + reading.unusedBytes
        let diff = abs(approxTotal - reading.totalBytes)
        XCTAssertLessThan(Double(diff) / Double(reading.totalBytes), 0.05)
        // Wired + Active + Inactive + Speculative should not exceed total
        let breakdown = reading.wiredBytes + reading.activeBytes + reading.inactiveBytes + reading.speculativeBytes
        XCTAssertLessThanOrEqual(breakdown, reading.totalBytes)
        // Pressure level is 0..2
        XCTAssertGreaterThanOrEqual(reading.pressureLevel, 0)
        XCTAssertLessThanOrEqual(reading.pressureLevel, 2)
    }

    func testSwapRatesAreNonNegative() {
        let service = MemoryService()
        _ = service.readCurrent()  // baseline
        Thread.sleep(forTimeInterval: 0.5)
        let reading = service.readCurrent()
        XCTAssertGreaterThanOrEqual(reading.swapInPagesPerSec, 0)
        XCTAssertGreaterThanOrEqual(reading.swapOutPagesPerSec, 0)
    }
}
```

- [ ] **Step 2: Run, expect failure**

⌘U. Expected: "Cannot find type 'MemoryService' in scope".

- [ ] **Step 3: Implement the service**

```swift
import Foundation
import Darwin
import MachO

public final class MemoryService {
    public init() {}

    private var lastSwapIns: UInt64 = 0
    private var lastSwapOuts: UInt64 = 0
    private var lastSampleTime: Date?

    public func readCurrent() -> MemoryReading {
        let now = Date()
        let stats = vmStatistics64()
        let pageSize = vmPageSize()

        let total = physicalMemoryBytes()

        let wired       = Int64(stats.wire_count) * Int64(pageSize)
        let active      = Int64(stats.active_count) * Int64(pageSize)
        let inactive    = Int64(stats.inactive_count) * Int64(pageSize)
        let speculative = Int64(stats.speculative_count) * Int64(pageSize)
        let compressor  = Int64(stats.compressor_page_count) * Int64(pageSize)
        let purgeable   = Int64(stats.purgeable_count) * Int64(pageSize)
        let external    = Int64(stats.external_page_count) * Int64(pageSize)
        let fileBacked  = Int64(stats.external_page_count) * Int64(pageSize) // alias on macOS
        let unused      = Int64(stats.free_count + stats.speculative_count) * Int64(pageSize)

        let used = total - unused

        let swapIns  = UInt64(stats.swapins)
        let swapOuts = UInt64(stats.swapouts)
        let dt: Double = {
            guard let last = lastSampleTime else { return 1 }
            return max(0.001, now.timeIntervalSince(last))
        }()
        let swapInRate  = (lastSampleTime == nil) ? 0 : Double(swapIns &- lastSwapIns) / dt
        let swapOutRate = (lastSampleTime == nil) ? 0 : Double(swapOuts &- lastSwapOuts) / dt
        lastSwapIns = swapIns
        lastSwapOuts = swapOuts
        lastSampleTime = now

        return MemoryReading(
            timestamp: now,
            totalBytes: total,
            usedBytes: used,
            unusedBytes: unused,
            wiredBytes: wired,
            activeBytes: active,
            inactiveBytes: inactive,
            speculativeBytes: speculative,
            compressorBytes: compressor,
            purgeableBytes: purgeable,
            externalBytes: external,
            fileBackedBytes: fileBacked,
            swapInPagesPerSec: max(0, swapInRate),
            swapOutPagesPerSec: max(0, swapOutRate),
            pressureLevel: pressureLevel()
        )
    }

    // MARK: - kernel calls

    private func physicalMemoryBytes() -> Int64 {
        var size: UInt64 = 0
        var sizeOfSize = MemoryLayout<UInt64>.size
        if sysctlbyname("hw.memsize", &size, &sizeOfSize, nil, 0) == 0 {
            return Int64(size)
        }
        return Int64(ProcessInfo.processInfo.physicalMemory)
    }

    private func vmPageSize() -> Int {
        var size: vm_size_t = 0
        host_page_size(mach_host_self(), &size)
        return Int(size)
    }

    private func vmStatistics64() -> vm_statistics64 {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
        let host = mach_host_self()
        let kr = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(host, HOST_VM_INFO64, $0, &count)
            }
        }
        guard kr == KERN_SUCCESS else { return vm_statistics64() }
        return stats
    }

    private func pressureLevel() -> Int {
        var level: Int32 = 0
        var size = MemoryLayout<Int32>.size
        // sysctl key: kern.memorystatus_vm_pressure_level (1=normal, 2=warn, 4=critical)
        if sysctlbyname("kern.memorystatus_vm_pressure_level", &level, &size, nil, 0) == 0 {
            switch level {
            case 1: return 0
            case 2: return 1
            case 4: return 2
            default: return 0
            }
        }
        return 0
    }
}
```

- [ ] **Step 4: Run tests, expect pass**

⌘U. Expected: both `testReadCurrentReturnsPlausibleValues` and `testSwapRatesAreNonNegative` pass.

- [ ] **Step 5: Commit**

```bash
git add RamKiller/Core/Services/MemoryService.swift RamKillerTests/MemoryServiceTests.swift
git commit -m "phase-1: add MemoryService"
```

---

## Task 3: `MemorySnapshot` SwiftData model

**Files:**
- Create: `/Users/a77/RamKiller/RamKiller/Core/Models/MemorySnapshot.swift`

- [ ] **Step 1: Write the model**

```swift
import Foundation
import SwiftData

@Model
public final class MemorySnapshot {
    @Attribute(.unique) public var id: UUID
    public var timestamp: Date
    public var totalBytes: Int64
    public var usedBytes: Int64
    public var unusedBytes: Int64
    public var wiredBytes: Int64
    public var activeBytes: Int64
    public var inactiveBytes: Int64
    public var speculativeBytes: Int64
    public var compressorBytes: Int64
    public var swapInPagesPerSec: Double
    public var swapOutPagesPerSec: Double
    public var pressureLevel: Int

    public init(reading: MemoryReading) {
        self.id = UUID()
        self.timestamp = reading.timestamp
        self.totalBytes = reading.totalBytes
        self.usedBytes = reading.usedBytes
        self.unusedBytes = reading.unusedBytes
        self.wiredBytes = reading.wiredBytes
        self.activeBytes = reading.activeBytes
        self.inactiveBytes = reading.inactiveBytes
        self.speculativeBytes = reading.speculativeBytes
        self.compressorBytes = reading.compressorBytes
        self.swapInPagesPerSec = reading.swapInPagesPerSec
        self.swapOutPagesPerSec = reading.swapOutPagesPerSec
        self.pressureLevel = reading.pressureLevel
    }
}
```

- [ ] **Step 2: Verify build**

⌘B.

- [ ] **Step 3: Commit**

```bash
git add RamKiller/Core/Models/MemorySnapshot.swift
git commit -m "phase-1: add MemorySnapshot @Model"
```

---

## Task 4: `ProcessReading` value type

**Files:**
- Create: `/Users/a77/RamKiller/RamKiller/Core/Models/ProcessReading.swift`

- [ ] **Step 1: Write the file**

```swift
import Foundation

public struct ProcessReading: Sendable, Identifiable, Equatable {
    public let id: pid_t            // PID is the natural id
    public let pid: pid_t
    public let name: String
    public let bundleId: String?
    public let executablePath: String?
    public let user: String
    public let rssBytes: Int64
    public let cpuPercent: Double
    public let startedAt: Date
    public var elapsedSeconds: Int { Int(Date().timeIntervalSince(startedAt)) }
}
```

- [ ] **Step 2: Commit**

```bash
git add RamKiller/Core/Models/ProcessReading.swift
git commit -m "phase-1: add ProcessReading struct"
```

---

## Task 5: `ProcessService` — read process list

**Files:**
- Create: `/Users/a77/RamKiller/RamKiller/Core/Services/ProcessService.swift`
- Test: `/Users/a77/RamKiller/RamKillerTests/ProcessServiceTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import RamKiller

final class ProcessServiceTests: XCTestCase {
    func testReadAllReturnsCurrentProcess() {
        let service = ProcessService()
        let all = service.readAll()
        XCTAssertGreaterThan(all.count, 50, "Mac always has 50+ processes")
        let me = ProcessInfo.processInfo.processIdentifier
        XCTAssertNotNil(all.first { $0.pid == me })
    }

    func testTopByRSSReturnsAtMostNAndIsSorted() {
        let service = ProcessService()
        let top = service.topByRSS(limit: 30)
        XCTAssertLessThanOrEqual(top.count, 30)
        for i in 1..<top.count {
            XCTAssertGreaterThanOrEqual(top[i-1].rssBytes, top[i].rssBytes)
        }
    }

    func testEachProcessHasNonEmptyName() {
        let service = ProcessService()
        let all = service.readAll()
        let nonEmpty = all.filter { !$0.name.isEmpty }
        // > 90% should have a parsable name; some kernel procs may not
        XCTAssertGreaterThan(Double(nonEmpty.count) / Double(all.count), 0.9)
    }
}
```

- [ ] **Step 2: Run, expect failure**

⌘U. Expected: "Cannot find type 'ProcessService' in scope".

- [ ] **Step 3: Implement the service**

```swift
import Foundation
import Darwin

public final class ProcessService {
    public init() {}

    public func readAll() -> [ProcessReading] {
        let pids = listPIDs()
        return pids.compactMap { reading(for: $0) }
    }

    public func topByRSS(limit: Int) -> [ProcessReading] {
        readAll().sorted { $0.rssBytes > $1.rssBytes }.prefix(limit).map { $0 }
    }

    // MARK: - libproc bridge

    private func listPIDs() -> [pid_t] {
        let bufferSize = proc_listallpids(nil, 0)
        guard bufferSize > 0 else { return [] }
        let count = Int(bufferSize) / MemoryLayout<pid_t>.stride
        var pids = [pid_t](repeating: 0, count: count)
        let written = pids.withUnsafeMutableBufferPointer {
            proc_listallpids($0.baseAddress, Int32($0.count * MemoryLayout<pid_t>.stride))
        }
        guard written > 0 else { return [] }
        return Array(pids.prefix(Int(written) / MemoryLayout<pid_t>.stride)).filter { $0 > 0 }
    }

    private func reading(for pid: pid_t) -> ProcessReading? {
        var taskInfo = proc_taskallinfo()
        let n = proc_pidinfo(pid, PROC_PIDTASKALLINFO, 0, &taskInfo, Int32(MemoryLayout<proc_taskallinfo>.stride))
        guard n == MemoryLayout<proc_taskallinfo>.stride else { return nil }

        let rss = Int64(taskInfo.ptinfo.pti_resident_size)
        let name = withUnsafePointer(to: &taskInfo.pbsd.pbi_comm) {
            $0.withMemoryRebound(to: CChar.self, capacity: Int(MAXCOMLEN) + 1) { String(cString: $0) }
        }
        let startSec = TimeInterval(taskInfo.pbsd.pbi_start_tvsec)
        let started = Date(timeIntervalSince1970: startSec)
        let cpu = cpuPercent(for: pid)

        let path = executablePath(for: pid)
        let user = userName(uid: taskInfo.pbsd.pbi_uid)

        return ProcessReading(
            id: pid,
            pid: pid,
            name: name,
            bundleId: nil,                       // bundle id requires NSRunningApplication; populated lazily by UI
            executablePath: path,
            user: user,
            rssBytes: rss,
            cpuPercent: cpu,
            startedAt: started
        )
    }

    private func cpuPercent(for pid: pid_t) -> Double {
        // proc_pid_rusage gives cumulative CPU; for "percent" we'd need deltas.
        // For Phase 1 we report 0 and revisit in Phase 2 if needed for Smart Kill banner.
        return 0
    }

    private func executablePath(for pid: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: Int(PROC_PIDPATHINFO_MAXSIZE))
        let n = proc_pidpath(pid, &buffer, UInt32(buffer.count))
        guard n > 0 else { return nil }
        return String(cString: buffer)
    }

    private func userName(uid: UInt32) -> String {
        guard let pwd = getpwuid(uid_t(uid)), let cName = pwd.pointee.pw_name else { return "?" }
        return String(cString: cName)
    }
}
```

- [ ] **Step 4: Run tests, expect pass**

⌘U.

- [ ] **Step 5: Commit**

```bash
git add RamKiller/Core/Services/ProcessService.swift RamKillerTests/ProcessServiceTests.swift
git commit -m "phase-1: add ProcessService"
```

---

## Task 6: `ProcessSnapshot` SwiftData model

**Files:**
- Create: `/Users/a77/RamKiller/RamKiller/Core/Models/ProcessSnapshot.swift`

- [ ] **Step 1: Write the model**

```swift
import Foundation
import SwiftData

@Model
public final class ProcessSnapshot {
    @Attribute(.unique) public var id: UUID
    public var timestamp: Date
    public var pid: Int32
    public var name: String
    public var bundleId: String?
    public var rssBytes: Int64
    public var cpuPercent: Double
    public var elapsedSeconds: Int

    public init(reading: ProcessReading, timestamp: Date) {
        self.id = UUID()
        self.timestamp = timestamp
        self.pid = reading.pid
        self.name = reading.name
        self.bundleId = reading.bundleId
        self.rssBytes = reading.rssBytes
        self.cpuPercent = reading.cpuPercent
        self.elapsedSeconds = reading.elapsedSeconds
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add RamKiller/Core/Models/ProcessSnapshot.swift
git commit -m "phase-1: add ProcessSnapshot @Model"
```

---

## Task 7: Wire `ModelContainer` into `RamKillerApp`

**Files:**
- Modify: `/Users/a77/RamKiller/RamKiller/App/RamKillerApp.swift`

- [ ] **Step 1: Replace the file**

```swift
import SwiftUI
import SwiftData

@main
struct RamKillerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    let container: ModelContainer = {
        let schema = Schema([MemorySnapshot.self, ProcessSnapshot.self])
        let url = URL.applicationSupportDirectory.appending(path: "RamKiller/db.store")
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let config = ModelConfiguration(schema: schema, url: url)
        return try! ModelContainer(for: schema, configurations: [config])
    }()

    var body: some Scene {
        Window("RamKiller", id: "main") {
            MainContentView()
                .frame(minWidth: 900, minHeight: 600)
        }
        .modelContainer(container)

        MenuBarExtra {
            MenuBarView()
                .modelContainer(container)
        } label: {
            MenuBarIcon()
        }
        .menuBarExtraStyle(.window)
    }
}
```

(The new `MenuBarIcon()` view comes in Task 12. For now, replace it with `Image(systemName: "memorychip")` if you want to compile incrementally.)

- [ ] **Step 2: Compile (using temporary placeholder for icon)**

For incremental compile, temporarily change `MenuBarIcon()` to `Image(systemName: "memorychip")` and ⌘B. Restore in Task 12.

- [ ] **Step 3: Commit**

```bash
git add RamKiller/App/RamKillerApp.swift
git commit -m "phase-1: install ModelContainer in scenes"
```

---

## Task 8: `SamplingCoordinator` — owns the timers

**Files:**
- Create: `/Users/a77/RamKiller/RamKiller/Core/Services/SamplingCoordinator.swift`

- [ ] **Step 1: Write the coordinator**

```swift
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
        memoryTimer = Timer.scheduledTimer(withTimeInterval: Self.memoryInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.sampleMemory() }
        }
        processTimer = Timer.scheduledTimer(withTimeInterval: Self.processInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.sampleProcesses() }
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
```

- [ ] **Step 2: Commit**

```bash
git add RamKiller/Core/Services/SamplingCoordinator.swift
git commit -m "phase-1: add SamplingCoordinator"
```

---

## Task 9: `RetentionService` — hourly pruning

**Files:**
- Create: `/Users/a77/RamKiller/RamKiller/Core/Services/RetentionService.swift`
- Test: `/Users/a77/RamKiller/RamKillerTests/RetentionServiceTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
import SwiftData
@testable import RamKiller

final class RetentionServiceTests: XCTestCase {
    func testPruneRemovesRecordsOlderThanCutoff() throws {
        let schema = Schema([MemorySnapshot.self, ProcessSnapshot.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let ctx = ModelContext(container)

        let now = Date()
        let oldReading = MemoryReading(
            timestamp: now.addingTimeInterval(-25 * 3600),
            totalBytes: 1, usedBytes: 0, unusedBytes: 0, wiredBytes: 0,
            activeBytes: 0, inactiveBytes: 0, speculativeBytes: 0, compressorBytes: 0,
            purgeableBytes: 0, externalBytes: 0, fileBackedBytes: 0,
            swapInPagesPerSec: 0, swapOutPagesPerSec: 0, pressureLevel: 0)
        let newReading = MemoryReading(
            timestamp: now,
            totalBytes: 1, usedBytes: 0, unusedBytes: 0, wiredBytes: 0,
            activeBytes: 0, inactiveBytes: 0, speculativeBytes: 0, compressorBytes: 0,
            purgeableBytes: 0, externalBytes: 0, fileBackedBytes: 0,
            swapInPagesPerSec: 0, swapOutPagesPerSec: 0, pressureLevel: 0)
        ctx.insert(MemorySnapshot(reading: oldReading))
        ctx.insert(MemorySnapshot(reading: newReading))
        try ctx.save()

        let service = RetentionService(retentionHours: 24)
        try service.prune(in: ctx, now: now)

        let remaining = try ctx.fetch(FetchDescriptor<MemorySnapshot>())
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining.first?.timestamp.timeIntervalSince1970, newReading.timestamp.timeIntervalSince1970, accuracy: 1)
    }
}
```

- [ ] **Step 2: Run, expect failure**

- [ ] **Step 3: Implement the service**

```swift
import Foundation
import SwiftData

public final class RetentionService {
    private let retentionHours: Int

    public init(retentionHours: Int = 24) {
        self.retentionHours = retentionHours
    }

    public func prune(in context: ModelContext, now: Date = Date()) throws {
        let cutoff = now.addingTimeInterval(-Double(retentionHours) * 3600)

        let memDescriptor = FetchDescriptor<MemorySnapshot>(
            predicate: #Predicate { $0.timestamp < cutoff }
        )
        for old in try context.fetch(memDescriptor) {
            context.delete(old)
        }

        let procDescriptor = FetchDescriptor<ProcessSnapshot>(
            predicate: #Predicate { $0.timestamp < cutoff }
        )
        for old in try context.fetch(procDescriptor) {
            context.delete(old)
        }

        try context.save()
    }
}
```

- [ ] **Step 4: Run tests, expect pass**

- [ ] **Step 5: Commit**

```bash
git add RamKiller/Core/Services/RetentionService.swift RamKillerTests/RetentionServiceTests.swift
git commit -m "phase-1: add RetentionService with TTL prune"
```

---

## Task 10: Schedule retention from app launch

**Files:**
- Modify: `/Users/a77/RamKiller/RamKiller/App/AppDelegate.swift`

- [ ] **Step 1: Add retention timer to delegate**

```swift
import AppKit
import SwiftData

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var retentionTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("RamKiller launched")
        scheduleRetention()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    private func scheduleRetention() {
        retentionTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { _ in
            Task { @MainActor in
                guard let container = await SharedContainer.container else { return }
                let ctx = ModelContext(container)
                try? RetentionService().prune(in: ctx)
            }
        }
    }
}

@MainActor
enum SharedContainer {
    static var container: ModelContainer?
}
```

- [ ] **Step 2: Wire `SharedContainer.container` from the app**

In `RamKillerApp.swift`, after the container is built:

```swift
init() {
    SharedContainer.container = container
}
```

(Add the `init()` to the `App` struct.)

- [ ] **Step 3: Commit**

```bash
git add RamKiller/App
git commit -m "phase-1: hourly retention scheduler"
```

---

## Task 11: `StatCard` reusable component

**Files:**
- Create: `/Users/a77/RamKiller/RamKiller/Features/Monitoring/StatCard.swift`

- [ ] **Step 1: Write the view**

```swift
import SwiftUI

struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String?
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .foregroundStyle(tint)
            if let sub = subtitle {
                Text(sub)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    HStack {
        StatCard(title: "Used", value: "28.3 GB", subtitle: "78%", tint: .accentColor)
        StatCard(title: "Unused", value: "7.5 GB", subtitle: "🟢 OK", tint: .green)
        StatCard(title: "Compressor", value: "6.1 GB", subtitle: nil, tint: .orange)
        StatCard(title: "Pressure", value: "Green", subtitle: nil, tint: .green)
    }
    .padding()
    .frame(width: 800)
}
```

- [ ] **Step 2: Commit**

```bash
git add RamKiller/Features/Monitoring/StatCard.swift
git commit -m "phase-1: add StatCard component"
```

---

## Task 12: `MenuBarIcon` — dynamic % rendered to NSImage

**Files:**
- Create: `/Users/a77/RamKiller/RamKiller/UI/MenuBar/MenuBarIcon.swift`

- [ ] **Step 1: Write the view**

```swift
import SwiftUI

struct MenuBarIcon: View {
    @EnvironmentObject private var coordinator: SamplingCoordinator

    var body: some View {
        Text(label)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .monospacedDigit()
    }

    private var label: String {
        guard let mem = coordinator.latestMemory else { return "—" }
        return "\(Int(mem.usedPercent.rounded()))%"
    }
}
```

- [ ] **Step 2: Replace the placeholder in `RamKillerApp.swift`**

In the `MenuBarExtra` label, replace the temporary `Image(systemName: "memorychip")` with:

```swift
MenuBarIcon()
    .environmentObject(samplingCoordinator)
```

Where `samplingCoordinator` is created in `RamKillerApp` with the container. Add the property:

```swift
@StateObject private var samplingCoordinator: SamplingCoordinator

init() {
    let schema = Schema([MemorySnapshot.self, ProcessSnapshot.self])
    let url = URL.applicationSupportDirectory.appending(path: "RamKiller/db.store")
    try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let config = ModelConfiguration(schema: schema, url: url)
    let container = try! ModelContainer(for: schema, configurations: [config])
    self.container = container
    SharedContainer.container = container
    self._samplingCoordinator = StateObject(wrappedValue: SamplingCoordinator(modelContext: ModelContext(container)))
}
```

And start the coordinator in `body` via `.onAppear`:

```swift
Window("RamKiller", id: "main") {
    MainContentView()
        .frame(minWidth: 900, minHeight: 600)
        .environmentObject(samplingCoordinator)
        .onAppear { samplingCoordinator.start() }
}
.modelContainer(container)
```

(Keep the coordinator alive via `@StateObject` — it keeps running even when the window closes.)

- [ ] **Step 3: Build and run, verify menubar shows live %**

⌘R. Expected: menubar text updates every ~2 s with current Used%.

- [ ] **Step 4: Commit**

```bash
git add RamKiller/UI/MenuBar/MenuBarIcon.swift RamKiller/App/RamKillerApp.swift
git commit -m "phase-1: live % in menubar"
```

---

## Task 13: Update `MenuBarView` with live numbers

**Files:**
- Modify: `/Users/a77/RamKiller/RamKiller/UI/MenuBar/MenuBarView.swift`

- [ ] **Step 1: Replace the view**

```swift
import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var coordinator: SamplingCoordinator
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let m = coordinator.latestMemory {
                row("Used", value: ByteFormat.gb(m.usedBytes) + " / " + ByteFormat.gb(m.totalBytes))
                row("Unused", value: ByteFormat.gb(m.unusedBytes), trailing: pressureBadge(m.pressureLevel))
                row("Compressor", value: ByteFormat.gb(m.compressorBytes))
                if m.swapOutPagesPerSec > 0 {
                    row("Swap out", value: "\(Int(m.swapOutPagesPerSec)) p/s", trailing: Text("⚠️"))
                }
            } else {
                Text("Sampling…").foregroundStyle(.secondary)
            }

            Divider().padding(.vertical, 4)

            if !coordinator.latestProcesses.isEmpty {
                Text("Top 5 by RSS").font(.caption).foregroundStyle(.secondary)
                ForEach(coordinator.latestProcesses.prefix(5)) { p in
                    HStack {
                        Text(p.name).lineLimit(1).truncationMode(.tail)
                        Spacer()
                        Text(ByteFormat.mb(p.rssBytes)).foregroundStyle(.secondary)
                    }
                    .font(.caption)
                }
                Divider().padding(.vertical, 4)
            }

            Button("Open Main Window") { openWindow(id: "main") }
            Button("Quit") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        }
        .padding(12)
        .frame(width: 260)
    }

    private func row(_ title: String, value: String, trailing: (some View)? = Text("")) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(value).monospacedDigit()
            if let t = trailing { t }
        }
        .font(.body)
    }

    private func pressureBadge(_ level: Int) -> some View {
        switch level {
        case 0: return Text("🟢").font(.caption)
        case 1: return Text("🟡").font(.caption)
        default: return Text("🔴").font(.caption)
        }
    }
}

enum ByteFormat {
    static func gb(_ b: Int64) -> String {
        let gb = Double(b) / (1024 * 1024 * 1024)
        return String(format: "%.1f GB", gb)
    }
    static func mb(_ b: Int64) -> String {
        let mb = Double(b) / (1024 * 1024)
        return String(format: "%.0f MB", mb)
    }
}
```

- [ ] **Step 2: Run, click menubar icon, verify**

⌘R. Expected: menubar dropdown shows live Used / Unused / Compressor + Top 5 processes.

- [ ] **Step 3: Commit**

```bash
git add RamKiller/UI/MenuBar/MenuBarView.swift
git commit -m "phase-1: live data in menubar dropdown"
```

---

## Task 14: `MemoryAreaChart`

**Files:**
- Create: `/Users/a77/RamKiller/RamKiller/Features/Monitoring/MemoryAreaChart.swift`

- [ ] **Step 1: Write the view**

```swift
import SwiftUI
import Charts
import SwiftData

struct MemoryAreaChart: View {
    @Query(sort: \MemorySnapshot.timestamp) private var snapshots: [MemorySnapshot]
    let windowHours: Int

    init(windowHours: Int = 1) {
        let cutoff = Date().addingTimeInterval(-Double(windowHours) * 3600)
        let predicate = #Predicate<MemorySnapshot> { $0.timestamp >= cutoff }
        _snapshots = Query(filter: predicate, sort: \MemorySnapshot.timestamp)
        self.windowHours = windowHours
    }

    var body: some View {
        Chart {
            ForEach(snapshots) { snap in
                AreaMark(
                    x: .value("Time", snap.timestamp),
                    y: .value("Used", Double(snap.usedBytes) / 1_073_741_824)
                )
                .foregroundStyle(by: .value("Series", "Used"))
                AreaMark(
                    x: .value("Time", snap.timestamp),
                    y: .value("Compressor", Double(snap.compressorBytes) / 1_073_741_824)
                )
                .foregroundStyle(by: .value("Series", "Compressor"))
            }
        }
        .chartForegroundStyleScale([
            "Used": Color.accentColor,
            "Compressor": Color.orange
        ])
        .chartYAxis {
            AxisMarks(format: Decimal.FormatStyle().precision(.fractionLength(0)))
        }
        .chartXAxis {
            AxisMarks(values: .automatic) { value in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.hour().minute())
            }
        }
        .frame(minHeight: 220)
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add RamKiller/Features/Monitoring/MemoryAreaChart.swift
git commit -m "phase-1: stacked area chart for Used/Compressor"
```

---

## Task 15: `PressureTimelineChart`

**Files:**
- Create: `/Users/a77/RamKiller/RamKiller/Features/Monitoring/PressureTimelineChart.swift`

- [ ] **Step 1: Write the view**

```swift
import SwiftUI
import Charts
import SwiftData

struct PressureTimelineChart: View {
    @Query(sort: \MemorySnapshot.timestamp) private var snapshots: [MemorySnapshot]

    init(windowHours: Int = 1) {
        let cutoff = Date().addingTimeInterval(-Double(windowHours) * 3600)
        let predicate = #Predicate<MemorySnapshot> { $0.timestamp >= cutoff }
        _snapshots = Query(filter: predicate, sort: \MemorySnapshot.timestamp)
    }

    var body: some View {
        Chart {
            ForEach(snapshots) { snap in
                BarMark(
                    x: .value("Time", snap.timestamp),
                    y: .value("Level", snap.pressureLevel + 1)
                )
                .foregroundStyle(color(for: snap.pressureLevel))
            }
        }
        .chartYScale(domain: 0...3)
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks(values: .automatic) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.hour().minute())
            }
        }
        .frame(height: 60)
    }

    private func color(for level: Int) -> Color {
        switch level {
        case 0: return .green.opacity(0.4)
        case 1: return .yellow.opacity(0.6)
        default: return .red.opacity(0.7)
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add RamKiller/Features/Monitoring/PressureTimelineChart.swift
git commit -m "phase-1: pressure timeline chart"
```

---

## Task 16: `SwapRateChart`

**Files:**
- Create: `/Users/a77/RamKiller/RamKiller/Features/Monitoring/SwapRateChart.swift`

- [ ] **Step 1: Write the view**

```swift
import SwiftUI
import Charts
import SwiftData

struct SwapRateChart: View {
    @Query(sort: \MemorySnapshot.timestamp) private var snapshots: [MemorySnapshot]

    init(windowHours: Int = 1) {
        let cutoff = Date().addingTimeInterval(-Double(windowHours) * 3600)
        let predicate = #Predicate<MemorySnapshot> { $0.timestamp >= cutoff }
        _snapshots = Query(filter: predicate, sort: \MemorySnapshot.timestamp)
    }

    var body: some View {
        Chart {
            ForEach(snapshots) { snap in
                LineMark(
                    x: .value("Time", snap.timestamp),
                    y: .value("Swap In", snap.swapInPagesPerSec),
                    series: .value("Series", "In")
                )
                .foregroundStyle(.blue)
                LineMark(
                    x: .value("Time", snap.timestamp),
                    y: .value("Swap Out", snap.swapOutPagesPerSec),
                    series: .value("Series", "Out")
                )
                .foregroundStyle(.red)
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.hour().minute())
            }
        }
        .frame(height: 140)
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add RamKiller/Features/Monitoring/SwapRateChart.swift
git commit -m "phase-1: swap rate chart"
```

---

## Task 17: `AdvancedBreakdownView`

**Files:**
- Create: `/Users/a77/RamKiller/RamKiller/Features/Monitoring/AdvancedBreakdownView.swift`

- [ ] **Step 1: Write the view**

```swift
import SwiftUI

struct AdvancedBreakdownView: View {
    @EnvironmentObject private var coordinator: SamplingCoordinator

    var body: some View {
        if let m = coordinator.latestMemory {
            VStack(alignment: .leading, spacing: 8) {
                Text("Advanced breakdown").font(.headline)
                HStack(spacing: 16) {
                    breakdown("Wired", bytes: m.wiredBytes)
                    breakdown("Active", bytes: m.activeBytes)
                    breakdown("Inactive", bytes: m.inactiveBytes)
                    breakdown("Speculative", bytes: m.speculativeBytes)
                }
                .font(.callout)
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func breakdown(_ title: String, bytes: Int64) -> some View {
        VStack(alignment: .leading) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(ByteFormat.gb(bytes)).monospacedDigit()
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add RamKiller/Features/Monitoring/AdvancedBreakdownView.swift
git commit -m "phase-1: advanced breakdown view"
```

---

## Task 18: `MonitoringView` dashboard

**Files:**
- Modify: `/Users/a77/RamKiller/RamKiller/Features/Monitoring/MonitoringView.swift`

- [ ] **Step 1: Replace the placeholder**

```swift
import SwiftUI

struct MonitoringView: View {
    @EnvironmentObject private var coordinator: SamplingCoordinator
    @AppStorage("monitoring.advanced") private var advanced: Bool = false
    @State private var windowHours: Int = 1

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                statCardsRow
                chartsSection
                if advanced { AdvancedBreakdownView() }
            }
            .padding(16)
        }
        .navigationTitle("Memory")
        .toolbar {
            ToolbarItem {
                Picker("Window", selection: $windowHours) {
                    Text("1h").tag(1)
                    Text("6h").tag(6)
                    Text("24h").tag(24)
                }
                .pickerStyle(.segmented)
            }
            ToolbarItem {
                Toggle("Advanced", isOn: $advanced)
            }
        }
    }

    @ViewBuilder
    private var statCardsRow: some View {
        if let m = coordinator.latestMemory {
            HStack(spacing: 12) {
                StatCard(
                    title: "Used",
                    value: ByteFormat.gb(m.usedBytes),
                    subtitle: String(format: "%.0f%%", m.usedPercent),
                    tint: .accentColor
                )
                StatCard(
                    title: "Unused",
                    value: ByteFormat.gb(m.unusedBytes),
                    subtitle: pressureLabel(m.pressureLevel),
                    tint: pressureColor(m.pressureLevel)
                )
                StatCard(
                    title: "Compressor",
                    value: ByteFormat.gb(m.compressorBytes),
                    subtitle: nil,
                    tint: .orange
                )
                StatCard(
                    title: "Total",
                    value: ByteFormat.gb(m.totalBytes),
                    subtitle: nil,
                    tint: .secondary
                )
            }
        } else {
            ProgressView().padding()
        }
    }

    private var chartsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Memory usage").font(.headline)
            MemoryAreaChart(windowHours: windowHours)
            Text("Pressure").font(.headline)
            PressureTimelineChart(windowHours: windowHours)
            Text("Swap activity (pages/sec)").font(.headline)
            SwapRateChart(windowHours: windowHours)
        }
    }

    private func pressureLabel(_ l: Int) -> String {
        switch l {
        case 0: return "🟢 OK"
        case 1: return "🟡 Warn"
        default: return "🔴 Critical"
        }
    }

    private func pressureColor(_ l: Int) -> Color {
        switch l {
        case 0: return .green
        case 1: return .yellow
        default: return .red
        }
    }
}
```

- [ ] **Step 2: Run app, navigate to Memory page, verify**

⌘R. Expected:
- 4 stat cards across the top.
- Stacked area chart updates every 2 s.
- Pressure timeline shows green most of the time.
- Swap chart at 0 (unless your machine is actively swapping).
- Toggle "Advanced" → breakdown row appears.
- Picker switches 1h / 6h / 24h windows.

- [ ] **Step 3: Commit**

```bash
git add RamKiller/Features/Monitoring/MonitoringView.swift
git commit -m "phase-1: monitoring dashboard"
```

---

## Task 19: `ProcessRow` component

**Files:**
- Create: `/Users/a77/RamKiller/RamKiller/Features/Processes/ProcessRow.swift`

- [ ] **Step 1: Write the view**

```swift
import SwiftUI

struct ProcessRow: View {
    let process: ProcessReading

    var body: some View {
        HStack(spacing: 8) {
            Text(process.name)
                .lineLimit(1)
                .frame(maxWidth: 180, alignment: .leading)
            Text("\(process.pid)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(width: 64, alignment: .leading)
            Text(ByteFormat.mb(process.rssBytes))
                .monospacedDigit()
                .frame(width: 80, alignment: .trailing)
            Text(elapsed)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .trailing)
            Text(process.user)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 90, alignment: .leading)
        }
    }

    private var elapsed: String {
        let s = process.elapsedSeconds
        if s < 60 { return "\(s)s" }
        if s < 3600 { return "\(s / 60)m" }
        if s < 86400 { return String(format: "%dh", s / 3600) }
        return String(format: "%dd", s / 86400)
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add RamKiller/Features/Processes/ProcessRow.swift
git commit -m "phase-1: ProcessRow component"
```

---

## Task 20: `ProcessDetailView`

**Files:**
- Create: `/Users/a77/RamKiller/RamKiller/Features/Processes/ProcessDetailView.swift`

- [ ] **Step 1: Write the view**

```swift
import SwiftUI

struct ProcessDetailView: View {
    let process: ProcessReading

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(process.name).font(.title2)
                LabeledContent("PID", value: "\(process.pid)")
                LabeledContent("User", value: process.user)
                LabeledContent("RSS", value: ByteFormat.mb(process.rssBytes))
                LabeledContent("Started", value: process.startedAt.formatted(date: .numeric, time: .standard))
                if let path = process.executablePath {
                    LabeledContent("Path", value: path)
                        .lineLimit(3)
                }
                Spacer()
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add RamKiller/Features/Processes/ProcessDetailView.swift
git commit -m "phase-1: ProcessDetailView"
```

---

## Task 21: `ProcessesView` list + detail

**Files:**
- Modify: `/Users/a77/RamKiller/RamKiller/Features/Processes/ProcessesView.swift`

- [ ] **Step 1: Replace the placeholder**

```swift
import SwiftUI

struct ProcessesView: View {
    @EnvironmentObject private var coordinator: SamplingCoordinator
    @State private var search: String = ""
    @State private var selectedPID: pid_t?
    @State private var showAll: Bool = false

    private var visible: [ProcessReading] {
        let source = showAll ? ProcessService().readAll().sorted { $0.rssBytes > $1.rssBytes }
                             : coordinator.latestProcesses
        guard !search.isEmpty else { return source }
        return source.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    private var selected: ProcessReading? {
        guard let pid = selectedPID else { return nil }
        return visible.first { $0.pid == pid }
    }

    var body: some View {
        HSplitView {
            VStack(spacing: 0) {
                Table(visible, selection: $selectedPID) {
                    TableColumn("Name") { p in Text(p.name) }
                        .width(min: 180, ideal: 220)
                    TableColumn("PID") { p in Text("\(p.pid)").monospacedDigit() }
                        .width(80)
                    TableColumn("RSS") { p in Text(ByteFormat.mb(p.rssBytes)).monospacedDigit() }
                        .width(80)
                    TableColumn("User") { p in Text(p.user) }
                        .width(90)
                }
                Divider()
                HStack {
                    TextField("Search", text: $search)
                        .textFieldStyle(.roundedBorder)
                    Toggle("All processes", isOn: $showAll)
                }
                .padding(8)
            }
            .frame(minWidth: 480)

            Group {
                if let p = selected {
                    ProcessDetailView(process: p)
                } else {
                    ContentUnavailableView("Select a process", systemImage: "arrow.left")
                }
            }
            .frame(minWidth: 280)
        }
        .navigationTitle("Processes")
    }
}
```

- [ ] **Step 2: Run, navigate to Processes, verify**

⌘R. Expected:
- Table shows ~30 processes (Top 30 by RSS).
- Search filters live.
- "All processes" toggle expands to full list (~900 on a typical Mac).
- Click a row → right panel shows PID/User/Path/Started.

- [ ] **Step 3: Commit**

```bash
git add RamKiller/Features/Processes/ProcessesView.swift
git commit -m "phase-1: ProcessesView with table + detail"
```

---

## Task 22: Pass `samplingCoordinator` to all detail views

**Files:**
- Modify: `/Users/a77/RamKiller/RamKiller/UI/MainContentView.swift`
- Modify: `/Users/a77/RamKiller/RamKiller/App/RamKillerApp.swift` (already done in Task 12)

- [ ] **Step 1: Make MainContentView take the coordinator**

```swift
import SwiftUI

struct MainContentView: View {
    @State private var selection: SidebarItem? = .monitoring

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selection)
        } detail: {
            detailView
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch selection {
        case .monitoring:    MonitoringView()
        case .processes:     ProcessesView()
        case .automation:    AutomationView()
        case .cacheCleaner:  CacheCleanerView()
        case .largeFiles:    LargeFilesView()
        case .uninstaller:   UninstallerView()
        case .launchItems:   LaunchItemsView()
        case .settings:      SettingsView()
        case nil:            PlaceholderView(title: "Pick a tool", phase: "—", icon: "sidebar.left")
        }
    }
}
```

(The `@EnvironmentObject` chain is already wired through `RamKillerApp.body` via `.environmentObject(samplingCoordinator)` in Task 12.)

- [ ] **Step 2: Build, run, click between Memory ↔ Processes**

⌘R. Expected: both pages live-update.

- [ ] **Step 3: Commit (if any tweaks needed)**

```bash
git add RamKiller/UI/MainContentView.swift
git commit -m "phase-1: ensure environment passes through detail" --allow-empty
```

---

## Task 23: Final verification + Phase 1 acceptance

- [ ] **Step 1: Run the full test suite**

⌘U. All Phase 0 + Phase 1 tests must pass.

- [ ] **Step 2: Walk through the acceptance checklist**

| Check | Expected |
|---|---|
| Menubar shows live %, updates every 2 s | ✅ |
| Click menubar → Used/Unused/Compressor + Top 5 visible | ✅ |
| Memory page → 4 stat cards | ✅ |
| Memory page → 3 charts render and update | ✅ |
| 1h / 6h / 24h picker switches the chart window | ✅ |
| Advanced toggle shows Wired/Active/Inactive/Speculative | ✅ |
| Processes page → Top 30 table | ✅ |
| Click a process → detail panel populated | ✅ |
| Search filters live | ✅ |
| "All processes" toggle expands to full list | ✅ |
| Close main window → menubar still updates | ✅ |
| Reopen window → data shows historical 1 h chart | ✅ |
| Wait 1 h → retention task runs (verify by leaving running) | ✅ (or visually inspect db.store size in Application Support) |

- [ ] **Step 3: Final commit if anything tweaked**

```bash
git add -A
git commit -m "phase-1: post-verification fixes" --allow-empty
```

---

## Phase 1 Acceptance Criteria

- [ ] All XCTest pass (`MemoryServiceTests`, `ProcessServiceTests`, `RetentionServiceTests`, `SidebarItemTests`, `LoginItemServiceTests`, `RamKillerTests`).
- [ ] Memory page replaces `vm_stat`/`top` for live monitoring.
- [ ] Process list replaces `ps`/`pgrep`.
- [ ] Charts cover 1 h / 6 h / 24 h.
- [ ] Pressure level reflects real `kern.memorystatus_vm_pressure_level`.
- [ ] Swap rates non-zero only when machine actually swaps.
- [ ] DB grows linearly and prunes hourly.

If all check, Phase 1 is complete — proceed to `2026-04-30-phase-2-actions.md`.
