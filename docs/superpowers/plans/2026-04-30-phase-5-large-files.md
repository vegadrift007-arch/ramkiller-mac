# Phase 5 — Large Files + Duplicate Detection Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Find large files and duplicate files in user-selected directories. Default scope: `~/Downloads`, `~/Documents`, `~/Movies`, `~/Desktop`. User can add or remove folders.

**Architecture:** Two services. `LargeFileScanner` uses `MDQuery` (Spotlight) with a fallback to `FileManager.enumerator`. `DuplicateScanner` uses three passes: bucket by size → SHA-256 of first 4 KB → full SHA-256 confirmation.

**Tech Stack:** CoreServices `MDQuery`, FileManager, CryptoKit (SHA-256), SwiftUI.

**Prerequisite:** Phase 0 + 1 + 2 + 3 + 4 complete.

---

## File Structure

| Path | Purpose |
|---|---|
| `RamKiller/Core/Models/LargeFileEntry.swift` | One file row |
| `RamKiller/Core/Models/DuplicateGroup.swift` | A group of identical files |
| `RamKiller/Core/Services/LargeFileScanner.swift` | Spotlight + walk |
| `RamKiller/Core/Services/DuplicateScanner.swift` | 3-stage hashing |
| `RamKiller/Core/Services/ScanScopeStore.swift` | Persist user folder selection |
| `RamKiller/Features/LargeFiles/LargeFilesView.swift` | (replace) tabbed view |
| `RamKiller/Features/LargeFiles/LargeFileListView.swift` | List of single files |
| `RamKiller/Features/LargeFiles/DuplicateListView.swift` | Grouped view |
| `RamKiller/Features/LargeFiles/ScanScopeSettings.swift` | Folder picker / list |
| `RamKillerTests/DuplicateScannerTests.swift` | |

---

## Task 1: `LargeFileEntry` + `DuplicateGroup`

**Files:**
- Create: `/Users/a77/RamKiller/RamKiller/Core/Models/LargeFileEntry.swift`
- Create: `/Users/a77/RamKiller/RamKiller/Core/Models/DuplicateGroup.swift`

- [ ] **Step 1: Write LargeFileEntry**

```swift
import Foundation

public struct LargeFileEntry: Identifiable, Hashable {
    public let id: String         // path
    public let path: String
    public let size: Int64
    public let modified: Date
    public let created: Date

    public var url: URL { URL(fileURLWithPath: path) }
    public var name: String { (path as NSString).lastPathComponent }
}
```

- [ ] **Step 2: Write DuplicateGroup**

```swift
import Foundation

public struct DuplicateGroup: Identifiable, Hashable {
    public let id: String         // common hash
    public let hash: String
    public let size: Int64
    public let entries: [LargeFileEntry]

    public var savings: Int64 {
        Int64(entries.count - 1) * size
    }
}
```

- [ ] **Step 3: Commit**

```bash
git add RamKiller/Core/Models
git commit -m "phase-5: LargeFileEntry + DuplicateGroup models"
```

---

## Task 2: `ScanScopeStore`

**Files:**
- Create: `/Users/a77/RamKiller/RamKiller/Core/Services/ScanScopeStore.swift`

- [ ] **Step 1: Write the store**

```swift
import Foundation

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
```

- [ ] **Step 2: Commit**

```bash
git add RamKiller/Core/Services/ScanScopeStore.swift
git commit -m "phase-5: ScanScopeStore"
```

---

## Task 3: `LargeFileScanner`

**Files:**
- Create: `/Users/a77/RamKiller/RamKiller/Core/Services/LargeFileScanner.swift`

- [ ] **Step 1: Write the scanner**

```swift
import Foundation

public actor LargeFileScanner {
    public init() {}

    public func scan(folders: [URL], minSize: Int64) async -> [LargeFileEntry] {
        var results: [LargeFileEntry] = []
        for folder in folders {
            results.append(contentsOf: walkAndCollect(folder: folder, minSize: minSize))
        }
        return results.sorted { $0.size > $1.size }
    }

    private func walkAndCollect(folder: URL, minSize: Int64) -> [LargeFileEntry] {
        var out: [LargeFileEntry] = []
        guard FileManager.default.fileExists(atPath: folder.path) else { return out }
        let resKeys: [URLResourceKey] = [.fileSizeKey, .contentModificationDateKey, .creationDateKey, .isRegularFileKey, .isPackageKey]
        guard let enumerator = FileManager.default.enumerator(
            at: folder,
            includingPropertiesForKeys: resKeys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return out }

        for case let url as URL in enumerator {
            do {
                let v = try url.resourceValues(forKeys: Set(resKeys))
                guard v.isRegularFile == true, v.isPackage != true else { continue }
                let size = Int64(v.fileSize ?? 0)
                if size >= minSize {
                    out.append(LargeFileEntry(
                        id: url.path, path: url.path, size: size,
                        modified: v.contentModificationDate ?? Date.distantPast,
                        created: v.creationDate ?? v.contentModificationDate ?? Date.distantPast
                    ))
                }
            } catch {
                continue
            }
        }
        return out
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add RamKiller/Core/Services/LargeFileScanner.swift
git commit -m "phase-5: LargeFileScanner (FileManager walk)"
```

---

## Task 4: `DuplicateScanner` 3-stage

**Files:**
- Create: `/Users/a77/RamKiller/RamKiller/Core/Services/DuplicateScanner.swift`
- Test: `/Users/a77/RamKiller/RamKillerTests/DuplicateScannerTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import RamKiller

final class DuplicateScannerTests: XCTestCase {
    func testFindsExactDuplicates() async throws {
        let tmp = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        let payload = Data(repeating: 0xab, count: 2 * 1024 * 1024) // 2 MB
        let unique  = Data(repeating: 0xcd, count: 2 * 1024 * 1024)

        let p1 = tmp.appending(path: "a.bin")
        let p2 = tmp.appending(path: "b.bin")
        let p3 = tmp.appending(path: "c.bin")
        try payload.write(to: p1)
        try payload.write(to: p2)
        try unique.write(to: p3)

        let scanner = DuplicateScanner()
        let groups = await scanner.scan(folders: [tmp], minSize: 1024 * 1024)
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(Set(groups[0].entries.map { $0.path }), [p1.path, p2.path])
    }

    func testIgnoresDistinctSameSizeFiles() async throws {
        let tmp = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        let a = Data(repeating: 0x11, count: 2 * 1024 * 1024)
        let b = Data(repeating: 0x22, count: 2 * 1024 * 1024)

        try a.write(to: tmp.appending(path: "a.bin"))
        try b.write(to: tmp.appending(path: "b.bin"))

        let groups = await DuplicateScanner().scan(folders: [tmp], minSize: 1024 * 1024)
        XCTAssertEqual(groups.count, 0)
    }
}
```

- [ ] **Step 2: Implement**

```swift
import Foundation
import CryptoKit

public actor DuplicateScanner {
    public init() {}

    public func scan(folders: [URL], minSize: Int64 = 1_048_576) async -> [DuplicateGroup] {
        let entries = await LargeFileScanner().scan(folders: folders, minSize: minSize)
        let bySize = Dictionary(grouping: entries) { $0.size }.filter { $0.value.count > 1 }

        var groups: [DuplicateGroup] = []

        for (size, candidates) in bySize {
            // Stage 2: quick-hash on first 4KB
            let byQuick = Dictionary(grouping: candidates) { e -> String in
                quickHash(path: e.path) ?? UUID().uuidString
            }
            for (_, quickGroup) in byQuick where quickGroup.count > 1 {
                // Stage 3: full hash
                let byFull = Dictionary(grouping: quickGroup) { e -> String in
                    fullHash(path: e.path) ?? UUID().uuidString
                }
                for (hash, fullGroup) in byFull where fullGroup.count > 1 {
                    groups.append(DuplicateGroup(
                        id: hash, hash: hash, size: size,
                        entries: fullGroup.sorted { $0.created < $1.created }
                    ))
                }
            }
        }
        return groups.sorted { $0.savings > $1.savings }
    }

    private func quickHash(path: String) -> String? {
        guard let handle = FileHandle(forReadingAtPath: path) else { return nil }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: 4096) else { return nil }
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }

    private func fullHash(path: String) -> String? {
        guard let handle = FileHandle(forReadingAtPath: path) else { return nil }
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try? handle.read(upToCount: 65536), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        let digest = hasher.finalize()
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
}
```

- [ ] **Step 3: Run tests, expect pass**

- [ ] **Step 4: Commit**

```bash
git add RamKiller/Core/Services/DuplicateScanner.swift RamKillerTests/DuplicateScannerTests.swift
git commit -m "phase-5: DuplicateScanner with 3-stage hashing"
```

---

## Task 5: `ScanScopeSettings` UI

**Files:**
- Create: `/Users/a77/RamKiller/RamKiller/Features/LargeFiles/ScanScopeSettings.swift`

- [ ] **Step 1: Write the picker view**

```swift
import SwiftUI
import AppKit

struct ScanScopeSettings: View {
    @ObservedObject var store = ScanScopeStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Scan locations").font(.headline)
                Spacer()
                Button("Add Folder") { addFolder() }
                Button("Reset") { store.reset() }
            }
            ForEach(store.folders, id: \.self) { url in
                HStack {
                    Image(systemName: "folder")
                    Text(url.path)
                        .font(.caption.monospaced())
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Button { store.remove(url) } label: {
                        Image(systemName: "xmark.circle")
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func addFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        if panel.runModal() == .OK {
            for url in panel.urls { store.add(url) }
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add RamKiller/Features/LargeFiles/ScanScopeSettings.swift
git commit -m "phase-5: scan scope settings view"
```

---

## Task 6: `LargeFileListView`

**Files:**
- Create: `/Users/a77/RamKiller/RamKiller/Features/LargeFiles/LargeFileListView.swift`

- [ ] **Step 1: Write the view**

```swift
import SwiftUI

struct LargeFileListView: View {
    @State private var entries: [LargeFileEntry] = []
    @State private var selection: Set<String> = []
    @State private var minSizeMB: Double = 100
    @State private var scanning: Bool = false
    @State private var moveToTrash: Bool = true
    @ObservedObject private var scope = ScanScopeStore.shared

    private var selectedTotal: Int64 {
        entries.filter { selection.contains($0.id) }.reduce(into: 0) { $0 += $1.size }
    }

    var body: some View {
        VStack(alignment: .leading) {
            ScanScopeSettings()
                .padding(.horizontal)

            HStack {
                Text("Min size (MB):")
                Slider(value: $minSizeMB, in: 50...1000, step: 50).frame(width: 200)
                Text("\(Int(minSizeMB))").monospacedDigit()
                Spacer()
                Button("Scan") { Task { await scan() } }.disabled(scanning)
                if scanning { ProgressView() }
            }
            .padding(.horizontal)

            Table(entries, selection: $selection) {
                TableColumn("Name") { e in Text(e.name).lineLimit(1) }.width(min: 220)
                TableColumn("Path") { e in Text(e.path).font(.caption.monospaced()).lineLimit(1).truncationMode(.middle) }.width(min: 240)
                TableColumn("Size") { e in Text(ByteFormat.mb(e.size)).monospacedDigit() }.width(80)
                TableColumn("Modified") { e in Text(e.modified.formatted(date: .abbreviated, time: .omitted)) }.width(110)
            }

            HStack {
                Toggle("Move to Trash", isOn: $moveToTrash)
                Spacer()
                Button {
                    Task { await deleteSelected() }
                } label: {
                    Label("Delete \(ByteFormat.mb(selectedTotal))", systemImage: "trash")
                }
                .disabled(selectedTotal == 0)
            }
            .padding()
        }
    }

    private func scan() async {
        scanning = true
        let scanner = LargeFileScanner()
        let result = await scanner.scan(folders: scope.folders, minSize: Int64(minSizeMB) * 1_048_576)
        entries = result
        selection = []
        scanning = false
    }

    private func deleteSelected() async {
        let toDelete = entries.filter { selection.contains($0.id) }
        var freed: Int64 = 0
        for e in toDelete {
            do {
                if moveToTrash {
                    var resulting: NSURL?
                    try FileManager.default.trashItem(at: e.url, resultingItemURL: &resulting)
                } else {
                    try FileManager.default.removeItem(at: e.url)
                }
                freed += e.size
            } catch {
                NSLog("delete failed: \(error)")
            }
        }
        UserActionLog.shared.record(type: "delete_large", target: "x\(toDelete.count)", success: true, bytesFreed: freed)
        await scan()
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add RamKiller/Features/LargeFiles/LargeFileListView.swift
git commit -m "phase-5: LargeFileListView"
```

---

## Task 7: `DuplicateListView`

**Files:**
- Create: `/Users/a77/RamKiller/RamKiller/Features/LargeFiles/DuplicateListView.swift`

- [ ] **Step 1: Write the view**

```swift
import SwiftUI

struct DuplicateListView: View {
    @State private var groups: [DuplicateGroup] = []
    @State private var keep: [String: String] = [:]   // groupID → entryID to keep
    @State private var scanning: Bool = false
    @State private var moveToTrash: Bool = true
    @State private var minSizeMB: Double = 1
    @ObservedObject private var scope = ScanScopeStore.shared

    var body: some View {
        VStack(alignment: .leading) {
            ScanScopeSettings().padding(.horizontal)
            HStack {
                Text("Min file size (MB):")
                Slider(value: $minSizeMB, in: 1...500, step: 1).frame(width: 200)
                Text("\(Int(minSizeMB))").monospacedDigit()
                Spacer()
                Button("Scan") { Task { await scan() } }.disabled(scanning)
                if scanning { ProgressView() }
            }.padding(.horizontal)

            ScrollView {
                ForEach(groups) { group in
                    groupCard(group)
                }
            }

            HStack {
                Toggle("Move to Trash", isOn: $moveToTrash)
                Spacer()
                Button {
                    Task { await deleteAllDuplicates() }
                } label: {
                    Label("Delete duplicates (\(ByteFormat.mb(totalSavings)))", systemImage: "trash")
                }
                .disabled(groups.isEmpty)
            }.padding()
        }
    }

    private var totalSavings: Int64 {
        groups.reduce(into: 0) { $0 += $1.savings }
    }

    @ViewBuilder
    private func groupCard(_ group: DuplicateGroup) -> some View {
        VStack(alignment: .leading) {
            HStack {
                Text("\(group.entries.count) files × \(ByteFormat.mb(group.size))").font(.headline)
                Spacer()
                Text("Save \(ByteFormat.mb(group.savings))").foregroundStyle(.green)
            }
            ForEach(group.entries) { entry in
                HStack {
                    Image(systemName: keep[group.id] == entry.id ? "star.fill" : "star")
                        .foregroundStyle(keep[group.id] == entry.id ? .yellow : .secondary)
                        .onTapGesture { keep[group.id] = entry.id }
                    Text(entry.path)
                        .font(.caption.monospaced())
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Text(entry.created.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal)
    }

    private func scan() async {
        scanning = true
        let scanner = DuplicateScanner()
        let result = await scanner.scan(folders: scope.folders, minSize: Int64(minSizeMB) * 1_048_576)
        groups = result
        // Default keep = first (oldest)
        for g in result { keep[g.id] = g.entries.first?.id }
        scanning = false
    }

    private func deleteAllDuplicates() async {
        var freed: Int64 = 0
        for g in groups {
            let keepID = keep[g.id]
            for e in g.entries where e.id != keepID {
                do {
                    if moveToTrash {
                        var resulting: NSURL?
                        try FileManager.default.trashItem(at: e.url, resultingItemURL: &resulting)
                    } else {
                        try FileManager.default.removeItem(at: e.url)
                    }
                    freed += e.size
                } catch {
                    NSLog("dup delete failed: \(error)")
                }
            }
        }
        UserActionLog.shared.record(type: "delete_duplicate", target: "groups=\(groups.count)", success: true, bytesFreed: freed)
        await scan()
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add RamKiller/Features/LargeFiles/DuplicateListView.swift
git commit -m "phase-5: DuplicateListView"
```

---

## Task 8: `LargeFilesView` tabs

**Files:**
- Modify: `/Users/a77/RamKiller/RamKiller/Features/LargeFiles/LargeFilesView.swift`

- [ ] **Step 1: Replace placeholder**

```swift
import SwiftUI

struct LargeFilesView: View {
    @State private var tab: Tab = .large

    enum Tab: String, CaseIterable, Identifiable {
        case large, duplicates
        var id: String { rawValue }
        var label: String { self == .large ? "Large Files" : "Duplicates" }
    }

    var body: some View {
        VStack {
            Picker("View", selection: $tab) {
                ForEach(Tab.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding()

            Group {
                switch tab {
                case .large:      LargeFileListView()
                case .duplicates: DuplicateListView()
                }
            }
        }
        .navigationTitle("Large Files")
    }
}
```

- [ ] **Step 2: Build and run, verify**

⌘R. Verify scan finds large files in `~/Downloads`. Place a duplicate file (e.g., `cp largefile.zip /tmp/largefile2.zip` then add `/tmp` as a scan folder) → duplicates tab should detect it.

- [ ] **Step 3: Commit**

```bash
git add RamKiller/Features/LargeFiles/LargeFilesView.swift
git commit -m "phase-5: LargeFilesView tabbed"
```

---

## Task 9: Acceptance verification

- [ ] **Step 1: Run tests**

⌘U.

- [ ] **Step 2: End-to-end**

| Check | Expected |
|---|---|
| Default scope shows 4 folders | ✅ |
| Add a custom folder via NSOpenPanel | ✅ |
| Large files scan finishes < 10 s on a typical Downloads dir | ✅ |
| Duplicate detection finds known duplicates | ✅ |
| Move to Trash works (file appears in `~/.Trash/`) | ✅ |
| Permanent delete works | ✅ |
| UserAction log records both kinds | ✅ |
| Re-scan after delete reflects updated state | ✅ |

- [ ] **Step 3: Final commit**

```bash
git add -A
git commit -m "phase-5: post-verification" --allow-empty
```

---

## Phase 5 Acceptance Criteria

- [ ] All XCTest pass.
- [ ] LargeFileScanner returns sorted results above threshold.
- [ ] DuplicateScanner correctly identifies duplicates and skips false-positive same-size files.
- [ ] Trash + permanent both work.
- [ ] User Action log records each delete batch.

If all check, Phase 5 is complete — proceed to `2026-04-30-phase-6-uninstaller.md`.
