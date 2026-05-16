# Phase 3 — Automation + Persistence Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add background automation: three-tier alert thresholds, optional auto-purge, persistent alert + user-action history, and a "pressure timeline" analytics view.

**Architecture:** A `ThresholdEngine` evaluates the latest `MemorySnapshot` against three rules every 2s tick. It writes `AlertEvent` rows when triggered, dispatches user notifications, optionally invokes `HelperBridge.send(.purgeMemory)`. A separate `UserActionLog` records every kill/purge from Phase 2 (retroactively wired). New analytics view aggregates 7/30 days of data.

**Tech Stack:** UserNotifications, SwiftData, Combine, Swift Charts (already imported).

**Prerequisite:** Phase 0 + 1 + 2 complete.

---

## File Structure

| Path | Purpose |
|---|---|
| `BeagleX/Core/Models/AlertEvent.swift` | SwiftData model |
| `BeagleX/Core/Models/UserAction.swift` | SwiftData model |
| `BeagleX/Core/Models/AlertLevel.swift` | enum (warning/critical/emergency) |
| `BeagleX/Core/Services/NotificationService.swift` | UserNotifications wrapper |
| `BeagleX/Core/Services/ThresholdEngine.swift` | Evaluator |
| `BeagleX/Core/Services/UserActionLog.swift` | Centralized action recording |
| `BeagleX/Core/Models/ThresholdConfig.swift` | Codable settings |
| `BeagleX/Features/Settings/AutomationSettingsSection.swift` | Threshold sliders + auto-purge toggle |
| `BeagleX/Features/Automation/AutomationView.swift` | (replace) full analytics view |
| `BeagleX/Features/Automation/PressureTimelineView.swift` | 7/30 day pressure bars |
| `BeagleX/Features/Automation/CulpritProcessesView.swift` | Top 10 during pressure |
| `BeagleX/Features/Automation/AlertHistoryView.swift` | Alert events list |
| `BeagleX/Features/Automation/UserActionHistoryView.swift` | Kill/purge history |
| `BeagleX/Core/Services/SamplingCoordinator.swift` | (modify) tick into ThresholdEngine |
| `BeagleX/Core/Services/HelperBridge.swift` | (modify) call UserActionLog on success |
| `BeagleX/Features/Processes/ProcessesView.swift` | (modify) call UserActionLog on kill |
| `BeagleX/UI/Components/PurgeButton.swift` | (modify) call UserActionLog on success |
| `BeagleX/App/BeagleXApp.swift` | (modify) extend Schema, request notif permission |
| `BeagleXTests/ThresholdEngineTests.swift` | |
| `BeagleXTests/UserActionLogTests.swift` | |

---

## Task 1: Define `AlertLevel`

**Files:**
- Create: `/Users/a77/BeagleX/BeagleX/Core/Models/AlertLevel.swift`

- [ ] **Step 1: Write enum**

```swift
import Foundation

public enum AlertLevel: String, Codable, CaseIterable {
    case warning
    case critical
    case emergency

    public var label: String {
        switch self {
        case .warning:   return "Warning"
        case .critical:  return "Critical"
        case .emergency: return "Emergency"
        }
    }

    public var icon: String {
        switch self {
        case .warning:   return "exclamationmark.triangle"
        case .critical:  return "flame"
        case .emergency: return "exclamationmark.octagon"
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add BeagleX/Core/Models/AlertLevel.swift
git commit -m "phase-3: AlertLevel enum"
```

---

## Task 2: `AlertEvent` SwiftData model

**Files:**
- Create: `/Users/a77/BeagleX/BeagleX/Core/Models/AlertEvent.swift`

- [ ] **Step 1: Write model**

```swift
import Foundation
import SwiftData

@Model
public final class AlertEvent {
    @Attribute(.unique) public var id: UUID
    public var timestamp: Date
    public var levelRaw: String
    public var trigger: String
    public var resolvedAt: Date?
    public var userActionTaken: String?

    public var level: AlertLevel {
        AlertLevel(rawValue: levelRaw) ?? .warning
    }

    public init(level: AlertLevel, trigger: String, timestamp: Date = Date()) {
        self.id = UUID()
        self.timestamp = timestamp
        self.levelRaw = level.rawValue
        self.trigger = trigger
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add BeagleX/Core/Models/AlertEvent.swift
git commit -m "phase-3: AlertEvent @Model"
```

---

## Task 3: `UserAction` SwiftData model

**Files:**
- Create: `/Users/a77/BeagleX/BeagleX/Core/Models/UserAction.swift`

- [ ] **Step 1: Write model**

```swift
import Foundation
import SwiftData

@Model
public final class UserAction {
    @Attribute(.unique) public var id: UUID
    public var timestamp: Date
    public var actionType: String          // "purge", "kill", "force_kill", "auto_purge"
    public var targetIdentifier: String?
    public var bytesFreed: Int64?
    public var success: Bool
    public var errorText: String?

    public init(type: String, target: String?, success: Bool, error: String? = nil, bytesFreed: Int64? = nil, timestamp: Date = Date()) {
        self.id = UUID()
        self.timestamp = timestamp
        self.actionType = type
        self.targetIdentifier = target
        self.success = success
        self.errorText = error
        self.bytesFreed = bytesFreed
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add BeagleX/Core/Models/UserAction.swift
git commit -m "phase-3: UserAction @Model"
```

---

## Task 4: Extend the Schema and ModelContainer

**Files:**
- Modify: `/Users/a77/BeagleX/BeagleX/App/BeagleXApp.swift`

- [ ] **Step 1: Update the `init()` schema**

```swift
let schema = Schema([
    MemorySnapshot.self,
    ProcessSnapshot.self,
    AlertEvent.self,
    UserAction.self
])
```

- [ ] **Step 2: Build and run; verify migration is automatic**

⌘R. SwiftData adds the new tables on first run.

- [ ] **Step 3: Commit**

```bash
git add BeagleX/App/BeagleXApp.swift
git commit -m "phase-3: extend Schema with AlertEvent + UserAction"
```

---

## Task 5: `UserActionLog` service

**Files:**
- Create: `/Users/a77/BeagleX/BeagleX/Core/Services/UserActionLog.swift`
- Test: `/Users/a77/BeagleX/BeagleXTests/UserActionLogTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
import SwiftData
@testable import BeagleX

final class UserActionLogTests: XCTestCase {
    func testRecordPersistsRow() throws {
        let schema = Schema([UserAction.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let log = UserActionLog(context: ModelContext(container))

        log.record(type: "purge", target: nil, success: true)
        log.record(type: "kill", target: "1234", success: false, error: "no permission")

        let ctx = ModelContext(container)
        let all = try ctx.fetch(FetchDescriptor<UserAction>())
        XCTAssertEqual(all.count, 2)
    }
}
```

- [ ] **Step 2: Implement**

```swift
import Foundation
import SwiftData

@MainActor
public final class UserActionLog {
    public static let shared: UserActionLog = {
        guard let container = SharedContainer.container else {
            fatalError("SharedContainer.container missing — wire it from BeagleXApp init")
        }
        return UserActionLog(context: ModelContext(container))
    }()

    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    public func record(type: String, target: String?, success: Bool, error: String? = nil, bytesFreed: Int64? = nil) {
        let action = UserAction(type: type, target: target, success: success, error: error, bytesFreed: bytesFreed)
        context.insert(action)
        try? context.save()
    }
}
```

- [ ] **Step 3: Run tests**

- [ ] **Step 4: Commit**

```bash
git add BeagleX/Core/Services/UserActionLog.swift BeagleXTests/UserActionLogTests.swift
git commit -m "phase-3: UserActionLog service"
```

---

## Task 6: Wire UserActionLog into Phase 2 actions

**Files:**
- Modify: `/Users/a77/BeagleX/BeagleX/UI/Components/PurgeButton.swift`
- Modify: `/Users/a77/BeagleX/BeagleX/Features/Processes/ProcessesView.swift`

- [ ] **Step 1: Log purges**

In `PurgeButton.fire()`, after `case .success: cooldown.markFired()`:

```swift
UserActionLog.shared.record(type: "purge", target: nil, success: true)
```

In the failure cases:

```swift
case .denied(let r):
    lastError = "Denied: \(r)"
    UserActionLog.shared.record(type: "purge", target: nil, success: false, error: r)
case .failed(let e):
    lastError = e
    UserActionLog.shared.record(type: "purge", target: nil, success: false, error: e)
```

- [ ] **Step 2: Log kills**

In `ProcessesView.performKill`:

```swift
let actionType = force ? "force_kill" : "kill"
let target = "\(process.pid):\(process.name)"
// ... after kill attempt completes:
UserActionLog.shared.record(type: actionType, target: target, success: kerr == 0)
```

(Adapt the local variable names to the actual code; `kerr` is the result returned from `kill(...)` or via the helper.)

- [ ] **Step 3: Build, run, perform a purge, perform a kill**

⌘R. Then check the database to confirm rows exist (you can also wait until Task 14 builds the UI).

- [ ] **Step 4: Commit**

```bash
git add BeagleX/UI/Components/PurgeButton.swift BeagleX/Features/Processes/ProcessesView.swift
git commit -m "phase-3: log purges and kills to UserActionLog"
```

---

## Task 7: `ThresholdConfig` settings type

**Files:**
- Create: `/Users/a77/BeagleX/BeagleX/Core/Models/ThresholdConfig.swift`

- [ ] **Step 1: Write the type**

```swift
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
```

- [ ] **Step 2: Commit**

```bash
git add BeagleX/Core/Models/ThresholdConfig.swift
git commit -m "phase-3: ThresholdConfig"
```

---

## Task 8: `NotificationService`

**Files:**
- Create: `/Users/a77/BeagleX/BeagleX/Core/Services/NotificationService.swift`

- [ ] **Step 1: Write the service**

```swift
import Foundation
import UserNotifications

@MainActor
public final class NotificationService {
    public static let shared = NotificationService()
    private let center = UNUserNotificationCenter.current()

    public func requestAuthorization() async {
        do {
            try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            NSLog("[notif] auth failed: \(error)")
        }
    }

    public func deliver(level: AlertLevel, message: String, identifier: String) {
        let content = UNMutableNotificationContent()
        content.title = "BeagleX — \(level.label)"
        content.body = message
        content.sound = level == .emergency ? .defaultCritical : .default

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil  // immediate
        )
        center.add(request)
    }

    public func clear(identifier: String) {
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}
```

- [ ] **Step 2: Request authorization at app launch**

In `AppDelegate.applicationDidFinishLaunching`:

```swift
Task { @MainActor in
    await NotificationService.shared.requestAuthorization()
}
```

- [ ] **Step 3: Commit**

```bash
git add BeagleX/Core/Services/NotificationService.swift BeagleX/App/AppDelegate.swift
git commit -m "phase-3: NotificationService + request auth"
```

---

## Task 9: `ThresholdEngine`

**Files:**
- Create: `/Users/a77/BeagleX/BeagleX/Core/Services/ThresholdEngine.swift`
- Test: `/Users/a77/BeagleX/BeagleXTests/ThresholdEngineTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
import XCTest
@testable import BeagleX

final class ThresholdEngineTests: XCTestCase {
    func makeReading(unusedGB: Double, swapOut: Double, t: Date = Date()) -> MemoryReading {
        MemoryReading(
            timestamp: t,
            totalBytes: 36 * 1_073_741_824,
            usedBytes: Int64((36 - unusedGB) * 1_073_741_824),
            unusedBytes: Int64(unusedGB * 1_073_741_824),
            wiredBytes: 0, activeBytes: 0, inactiveBytes: 0, speculativeBytes: 0,
            compressorBytes: 0, purgeableBytes: 0, externalBytes: 0, fileBackedBytes: 0,
            swapInPagesPerSec: 0, swapOutPagesPerSec: swapOut, pressureLevel: 0
        )
    }

    func testWarningTriggersAfterHold() {
        let cfg = ThresholdConfig()
        let engine = ThresholdEngine(config: cfg)
        let now = Date()
        for i in 0...60 {
            let r = makeReading(unusedGB: 1.5, swapOut: 0, t: now.addingTimeInterval(Double(i)))
            _ = engine.evaluate(r)
        }
        let triggered = engine.evaluate(makeReading(unusedGB: 1.5, swapOut: 0, t: now.addingTimeInterval(61)))
        XCTAssertEqual(triggered, .warning)
    }

    func testNoTriggerIfBriefDip() {
        let cfg = ThresholdConfig()
        let engine = ThresholdEngine(config: cfg)
        let now = Date()
        _ = engine.evaluate(makeReading(unusedGB: 1.5, swapOut: 0, t: now))
        // Recover before hold elapses
        let triggered = engine.evaluate(makeReading(unusedGB: 5.0, swapOut: 0, t: now.addingTimeInterval(30)))
        XCTAssertNil(triggered)
    }

    func testEmergencyOnSwap() {
        let cfg = ThresholdConfig()
        let engine = ThresholdEngine(config: cfg)
        let now = Date()
        for i in 0...10 {
            _ = engine.evaluate(makeReading(unusedGB: 5.0, swapOut: 5.0, t: now.addingTimeInterval(Double(i))))
        }
        let trig = engine.evaluate(makeReading(unusedGB: 5.0, swapOut: 5.0, t: now.addingTimeInterval(11)))
        XCTAssertEqual(trig, .emergency)
    }
}
```

- [ ] **Step 2: Implement**

```swift
import Foundation

public final class ThresholdEngine {
    public var config: ThresholdConfig

    private var warningSince: Date?
    private var criticalSince: Date?
    private var emergencySince: Date?

    /// Last alert delivered (for de-duplication / cool-down).
    private var lastEmittedLevel: AlertLevel?
    private var lastEmittedAt: Date?

    public init(config: ThresholdConfig) {
        self.config = config
    }

    /// Evaluates the latest reading. Returns the level if a NEW alert should fire, else nil.
    public func evaluate(_ reading: MemoryReading) -> AlertLevel? {
        let unusedGB = Double(reading.unusedBytes) / 1_073_741_824
        let swapping = reading.swapOutPagesPerSec > 0

        // Maintain "since" timestamps
        if unusedGB < config.warningUnusedGB {
            if warningSince == nil { warningSince = reading.timestamp }
        } else { warningSince = nil }

        if unusedGB < config.criticalUnusedGB {
            if criticalSince == nil { criticalSince = reading.timestamp }
        } else { criticalSince = nil }

        if swapping {
            if emergencySince == nil { emergencySince = reading.timestamp }
        } else { emergencySince = nil }

        // Pick highest level whose hold duration is satisfied
        let now = reading.timestamp
        if let s = emergencySince, now.timeIntervalSince(s) >= Double(config.emergencyHoldSeconds) {
            return shouldEmit(.emergency, now: now) ? .emergency : nil
        }
        if let s = criticalSince, now.timeIntervalSince(s) >= Double(config.criticalHoldSeconds) {
            return shouldEmit(.critical, now: now) ? .critical : nil
        }
        if let s = warningSince, now.timeIntervalSince(s) >= Double(config.warningHoldSeconds) {
            return shouldEmit(.warning, now: now) ? .warning : nil
        }
        return nil
    }

    private func shouldEmit(_ level: AlertLevel, now: Date) -> Bool {
        // Same-or-lower level within 5 min → suppress; higher → always emit.
        let cooldown: TimeInterval = 300
        if let last = lastEmittedLevel, let lastT = lastEmittedAt {
            if level.rawValue == last.rawValue && now.timeIntervalSince(lastT) < cooldown {
                return false
            }
        }
        lastEmittedLevel = level
        lastEmittedAt = now
        return true
    }

    public func reset() {
        warningSince = nil; criticalSince = nil; emergencySince = nil
        lastEmittedLevel = nil; lastEmittedAt = nil
    }
}
```

- [ ] **Step 3: Run tests, expect pass**

- [ ] **Step 4: Commit**

```bash
git add BeagleX/Core/Services/ThresholdEngine.swift BeagleXTests/ThresholdEngineTests.swift
git commit -m "phase-3: ThresholdEngine with hold-duration logic"
```

---

## Task 10: Wire ThresholdEngine into SamplingCoordinator

**Files:**
- Modify: `/Users/a77/BeagleX/BeagleX/Core/Services/SamplingCoordinator.swift`

- [ ] **Step 1: Add engine + alert flow**

```swift
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
        memoryTimer = Timer.scheduledTimer(withTimeInterval: Self.memoryInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.sampleMemory() }
        }
        processTimer = Timer.scheduledTimer(withTimeInterval: Self.processInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.sampleProcesses() }
        }
    }

    public func stop() {
        memoryTimer?.invalidate(); processTimer?.invalidate()
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
           level.rawValue >= engine.config.autoPurgeAtLevel.rawValue {
            Task { await autoPurge() }
        }
    }

    private func autoPurge() async {
        do {
            let result = try await HelperBridge.shared.send(.purgeMemory)
            switch result {
            case .success:
                UserActionLog.shared.record(type: "auto_purge", target: nil, success: true)
            case .denied(let r):
                UserActionLog.shared.record(type: "auto_purge", target: nil, success: false, error: r)
            case .failed(let e):
                UserActionLog.shared.record(type: "auto_purge", target: nil, success: false, error: e)
            }
        } catch {
            UserActionLog.shared.record(type: "auto_purge", target: nil, success: false, error: error.localizedDescription)
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add BeagleX/Core/Services/SamplingCoordinator.swift
git commit -m "phase-3: wire ThresholdEngine into sampling tick"
```

---

## Task 11: `AutomationSettingsSection`

**Files:**
- Create: `/Users/a77/BeagleX/BeagleX/Features/Settings/AutomationSettingsSection.swift`

- [ ] **Step 1: Write the section**

```swift
import SwiftUI

struct AutomationSettingsSection: View {
    @State private var config: ThresholdConfig = .load()
    @EnvironmentObject private var coordinator: SamplingCoordinator

    var body: some View {
        Section("Automation") {
            VStack(alignment: .leading) {
                Text("Warning when Unused < \(config.warningUnusedGB, specifier: "%.1f") GB for \(config.warningHoldSeconds)s")
                Slider(value: $config.warningUnusedGB, in: 0.5...8.0, step: 0.5)
            }
            VStack(alignment: .leading) {
                Text("Critical when Unused < \(config.criticalUnusedGB, specifier: "%.1f") GB for \(config.criticalHoldSeconds)s")
                Slider(value: $config.criticalUnusedGB, in: 0.2...4.0, step: 0.1)
            }
            Toggle("Auto-purge on Critical/Emergency", isOn: $config.autoPurgeEnabled)
            Picker("Auto-purge from level", selection: $config.autoPurgeAtLevel) {
                ForEach(AlertLevel.allCases, id: \.self) { Text($0.label).tag($0) }
            }
            .disabled(!config.autoPurgeEnabled)
            Button("Save") {
                config.save()
                coordinator.updateThresholds(config)
            }
        }
    }
}
```

- [ ] **Step 2: Add to SettingsView**

In `SettingsView`, append `AutomationSettingsSection()` at the end of the `Form`.

- [ ] **Step 3: Commit**

```bash
git add BeagleX/Features/Settings/AutomationSettingsSection.swift BeagleX/Features/Settings/SettingsView.swift
git commit -m "phase-3: automation settings section"
```

---

## Task 12: `PressureTimelineView` (7/30 day analytics)

**Files:**
- Create: `/Users/a77/BeagleX/BeagleX/Features/Automation/PressureTimelineView.swift`

- [ ] **Step 1: Write the view**

```swift
import SwiftUI
import Charts
import SwiftData

struct PressureTimelineView: View {
    @Query private var snapshots: [MemorySnapshot]
    let days: Int

    init(days: Int) {
        self.days = days
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        let predicate = #Predicate<MemorySnapshot> { $0.timestamp >= cutoff }
        _snapshots = Query(filter: predicate, sort: \MemorySnapshot.timestamp)
    }

    private struct HourBucket: Identifiable {
        let id = UUID()
        let hour: Date
        let avgPressure: Double
    }

    private var buckets: [HourBucket] {
        let grouped = Dictionary(grouping: snapshots) { snap -> Date in
            let comp = Calendar.current.dateComponents([.year, .month, .day, .hour], from: snap.timestamp)
            return Calendar.current.date(from: comp) ?? snap.timestamp
        }
        return grouped.map { (hour, snaps) in
            let avg = snaps.map { Double($0.pressureLevel) }.reduce(0, +) / Double(max(snaps.count, 1))
            return HourBucket(hour: hour, avgPressure: avg)
        }
        .sorted { $0.hour < $1.hour }
    }

    var body: some View {
        Chart(buckets) { bucket in
            BarMark(
                x: .value("Hour", bucket.hour, unit: .hour),
                y: .value("Pressure", bucket.avgPressure)
            )
            .foregroundStyle(color(for: bucket.avgPressure))
        }
        .chartYScale(domain: 0...2)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 8))
        }
        .frame(height: 180)
    }

    private func color(for level: Double) -> Color {
        switch level {
        case ..<0.5:  return .green
        case ..<1.5:  return .yellow
        default:      return .red
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add BeagleX/Features/Automation/PressureTimelineView.swift
git commit -m "phase-3: pressure timeline analytics"
```

---

## Task 13: `CulpritProcessesView`

**Files:**
- Create: `/Users/a77/BeagleX/BeagleX/Features/Automation/CulpritProcessesView.swift`

- [ ] **Step 1: Write the view**

```swift
import SwiftUI
import SwiftData

struct CulpritProcessesView: View {
    @Query private var snapshots: [ProcessSnapshot]
    let days: Int

    init(days: Int) {
        self.days = days
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        let predicate = #Predicate<ProcessSnapshot> { $0.timestamp >= cutoff }
        _snapshots = Query(filter: predicate, sort: \ProcessSnapshot.timestamp)
    }

    private struct ProcAgg: Identifiable {
        let id: String
        let name: String
        let totalRSS: Int64
        let appearances: Int
    }

    private var top10: [ProcAgg] {
        let grouped = Dictionary(grouping: snapshots) { $0.name }
        let aggregates = grouped.map { (name, snaps) in
            ProcAgg(
                id: name,
                name: name,
                totalRSS: snaps.map { $0.rssBytes }.reduce(0, +),
                appearances: snaps.count
            )
        }
        return aggregates.sorted { $0.totalRSS > $1.totalRSS }.prefix(10).map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading) {
            Text("Top processes by aggregated RSS").font(.headline)
            Table(top10) {
                TableColumn("Name") { p in Text(p.name) }
                TableColumn("Total RSS") { p in Text(ByteFormat.gb(p.totalRSS)).monospacedDigit() }
                TableColumn("Sampled") { p in Text("\(p.appearances)").monospacedDigit() }
            }
            .frame(minHeight: 280)
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add BeagleX/Features/Automation/CulpritProcessesView.swift
git commit -m "phase-3: culprit processes view"
```

---

## Task 14: `AlertHistoryView` + `UserActionHistoryView`

**Files:**
- Create: `/Users/a77/BeagleX/BeagleX/Features/Automation/AlertHistoryView.swift`
- Create: `/Users/a77/BeagleX/BeagleX/Features/Automation/UserActionHistoryView.swift`

- [ ] **Step 1: Write AlertHistoryView**

```swift
import SwiftUI
import SwiftData

struct AlertHistoryView: View {
    @Query(sort: \AlertEvent.timestamp, order: .reverse) private var events: [AlertEvent]

    var body: some View {
        Table(events) {
            TableColumn("Time") { e in Text(e.timestamp.formatted(date: .abbreviated, time: .standard)) }
            TableColumn("Level") { e in
                Label(e.level.label, systemImage: e.level.icon)
            }
            TableColumn("Trigger") { e in Text(e.trigger) }
        }
        .frame(minHeight: 280)
    }
}
```

- [ ] **Step 2: Write UserActionHistoryView**

```swift
import SwiftUI
import SwiftData

struct UserActionHistoryView: View {
    @Query(sort: \UserAction.timestamp, order: .reverse) private var actions: [UserAction]

    var body: some View {
        Table(actions) {
            TableColumn("Time") { a in Text(a.timestamp.formatted(date: .abbreviated, time: .shortened)) }
            TableColumn("Type") { a in Text(a.actionType) }
            TableColumn("Target") { a in Text(a.targetIdentifier ?? "-") }
            TableColumn("Result") { a in
                if a.success {
                    Image(systemName: "checkmark.circle").foregroundStyle(.green)
                } else {
                    HStack {
                        Image(systemName: "xmark.circle").foregroundStyle(.red)
                        Text(a.errorText ?? "").font(.caption)
                    }
                }
            }
        }
        .frame(minHeight: 280)
    }
}
```

- [ ] **Step 3: Commit**

```bash
git add BeagleX/Features/Automation/AlertHistoryView.swift BeagleX/Features/Automation/UserActionHistoryView.swift
git commit -m "phase-3: alert + action history views"
```

---

## Task 15: `AutomationView` final layout

**Files:**
- Modify: `/Users/a77/BeagleX/BeagleX/Features/Automation/AutomationView.swift`

- [ ] **Step 1: Replace placeholder**

```swift
import SwiftUI

struct AutomationView: View {
    @State private var days: Int = 7
    @State private var tab: Tab = .timeline

    enum Tab: String, CaseIterable, Identifiable {
        case timeline, culprits, alerts, actions
        var id: String { rawValue }
        var label: String {
            switch self {
            case .timeline: return "Pressure Timeline"
            case .culprits: return "Culprit Processes"
            case .alerts:   return "Alert History"
            case .actions:  return "User Actions"
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Picker("Range", selection: $days) {
                    Text("7 days").tag(7); Text("30 days").tag(30)
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
                Spacer()
            }
            .padding(.horizontal)

            Picker("View", selection: $tab) {
                ForEach(Tab.allCases) { t in Text(t.label).tag(t) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            Group {
                switch tab {
                case .timeline: PressureTimelineView(days: days)
                case .culprits: CulpritProcessesView(days: days)
                case .alerts:   AlertHistoryView()
                case .actions:  UserActionHistoryView()
                }
            }
            .padding()
        }
        .navigationTitle("Automation")
    }
}
```

- [ ] **Step 2: Build and run, verify**

⌘R. Navigate to Automation. Switch tabs and date ranges; verify charts render.

- [ ] **Step 3: Commit**

```bash
git add BeagleX/Features/Automation/AutomationView.swift
git commit -m "phase-3: AutomationView with timeline/culprits/alerts/actions tabs"
```

---

## Task 16: Acceptance verification

- [ ] **Step 1: Trigger a test alert**

Temporarily lower thresholds in code to make Warning fire (e.g., set `warningUnusedGB = 100` in defaults), restart the app, wait 60s. A notification should appear and a row should show in Alert History.

Restore defaults after testing.

- [ ] **Step 2: Trigger auto-purge**

Enable auto-purge in Settings; lower critical threshold to a reachable number; observe a `auto_purge` UserAction logged after the alert fires.

- [ ] **Step 3: Verify retention still works for new tables**

Modify `RetentionService` (Phase 1, Task 9) to also include `AlertEvent` and `UserAction`? **Wait — these are designed to be permanent**, so we deliberately do NOT prune them. Verify by leaving the app running and confirming AlertEvent / UserAction rows accumulate.

- [ ] **Step 4: Run all tests**

⌘U. All Phase 0/1/2/3 tests pass.

- [ ] **Step 5: Final commit**

```bash
git add -A
git commit -m "phase-3: post-verification" --allow-empty
```

---

## Phase 3 Acceptance Criteria

- [ ] Three-tier alerts trigger and dispatch macOS notifications.
- [ ] Hold-duration logic prevents brief spikes from triggering alerts.
- [ ] Auto-purge can be toggled and respects the configured level + cooldown.
- [ ] AlertEvent and UserAction rows persist across app restarts (not retention-pruned).
- [ ] Pressure timeline shows 7/30 day data with hour-bucket aggregation.
- [ ] Culprit processes view ranks by aggregated RSS during pressure windows.
- [ ] Alert + action history tables show all events.
- [ ] All XCTest pass.

If all check, Phase 3 is complete — proceed to `2026-04-30-phase-4-cache-cleaner.md`.
