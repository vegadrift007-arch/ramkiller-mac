import SwiftUI

struct CacheCleanerView: View {
    @State private var sizes: [String: Int64] = [:]
    @State private var selectedIDs: Set<String> = []
    @State private var scanning: Bool = false
    @State private var scanProgress: Double = 0
    @State private var moveToTrash: Bool = true
    @State private var lastResult: [CleanerService.CleanResult] = []
    @State private var showConfirm: Bool = false

    private let kb = CleanerKnowledgeBase.shared

    private var selectedTotal: Int64 {
        kb.cleaners.filter { selectedIDs.contains($0.id) }
            .reduce(into: 0) { $0 += sizes[$1.id] ?? 0 }
    }

    /// While scanning we show everything (so user sees activity).
    /// After scan: only show cleaners with size > 0, and only categories that have at least one such cleaner.
    private var visibleCategories: [(CleanerCategory, [Cleaner])] {
        kb.byCategory().compactMap { (cat, items) in
            let filtered = items.filter { c in
                if scanning { return true }            // show all while scanning
                guard let s = sizes[c.id] else { return true }
                return s > 0
            }
            return filtered.isEmpty ? nil : (cat, filtered)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Sticky top bar
            HStack(spacing: 12) {
                Button("Scan") { Task { await scan() } }
                    .disabled(scanning)
                if scanning {
                    ProgressView(value: scanProgress).frame(width: 160)
                }
                Spacer()
                Toggle("Move to Trash", isOn: $moveToTrash)
                Button {
                    showConfirm = true
                } label: {
                    Label("Clean \(ByteFormat.mb(selectedTotal))", systemImage: "trash")
                }
                .disabled(selectedTotal == 0 || scanning)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // Cleaner list — hide rows with size = 0 once scan completes
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(visibleCategories, id: \.0) { (cat, items) in
                        CleanerCategorySection(
                            category: cat,
                            cleaners: items,
                            sizes: sizes,
                            selectedIDs: $selectedIDs
                        )
                        .padding(.horizontal, 12)
                    }
                    if !scanning && visibleCategories.isEmpty {
                        ContentUnavailableView(
                            "Nothing to clean",
                            systemImage: "checkmark.circle",
                            description: Text("No reclaimable cache found.")
                        )
                        .padding(.top, 40)
                    }
                }
                .padding(.vertical, 8)
            }

            if !lastResult.isEmpty {
                resultBanner
            }
        }
        .navigationTitle("Cache Cleaner")
        .toolbarBackground(Theme.bg, for: .windowToolbar)
        .toolbarBackground(.visible, for: .windowToolbar)
        .task { await scan() }
        .alert("Clean \(ByteFormat.mb(selectedTotal))?", isPresented: $showConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Clean", role: .destructive) { Task { await performClean() } }
        } message: {
            Text("This will \(moveToTrash ? "move to Trash" : "permanently delete") files matched by \(selectedIDs.count) cleaner\(selectedIDs.count > 1 ? "s" : "").")
        }
    }

    private var resultBanner: some View {
        let totalFreed = lastResult.reduce(into: Int64(0)) { $0 += $1.bytesFreed }
        let totalErrors = lastResult.reduce(into: 0) { $0 += $1.errors.count }
        return HStack {
            Image(systemName: "checkmark.circle").foregroundStyle(.green)
            Text("Freed \(ByteFormat.mb(totalFreed))" + (totalErrors > 0 ? " (\(totalErrors) errors)" : ""))
            Spacer()
            Button("Dismiss") { lastResult = [] }
        }
        .padding(8)
        .background(Color.green.opacity(0.1))
    }

    private func scan() async {
        scanning = true
        sizes = [:]
        selectedIDs = []
        let scanner = ScannerService()
        let total = Double(kb.cleaners.count)
        var done = 0
        await withTaskGroup(of: (String, Int64).self) { group in
            for c in kb.cleaners {
                group.addTask { (c.id, await scanner.computeSize(for: c)) }
            }
            for await (id, size) in group {
                sizes[id] = size
                done += 1
                scanProgress = Double(done) / total
            }
        }
        // Default-select 'safe' cleaners with > 0 bytes
        selectedIDs = Set(kb.cleaners.filter { $0.safety == .safe && (sizes[$0.id] ?? 0) > 0 }.map { $0.id })
        scanning = false
    }

    private func performClean() async {
        let toClean = kb.cleaners.filter { selectedIDs.contains($0.id) }
        let service = CleanerService()
        lastResult = await service.clean(toClean, moveToTrash: moveToTrash)
        await scan()  // re-scan to refresh sizes
    }
}
