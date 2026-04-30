import SwiftUI

struct LargeFileListView: View {
    @State private var entries: [LargeFileEntry] = []
    @State private var marked: Set<String> = []
    @State private var minSizeMB: Double = 100
    @State private var scanning: Bool = false
    @State private var moveToTrash: Bool = true
    @ObservedObject private var scope = ScanScopeStore.shared

    private var selectedTotal: Int64 {
        entries.filter { marked.contains($0.id) }.reduce(into: 0) { $0 += $1.size }
    }

    private var allSelected: Bool {
        !entries.isEmpty && marked.count == entries.count
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
                if scanning { ProgressView().controlSize(.small) }
            }
            .padding(.horizontal)

            // Selection toolbar
            HStack {
                Toggle(isOn: Binding(
                    get: { allSelected },
                    set: { isOn in
                        marked = isOn ? Set(entries.map { $0.id }) : []
                    }
                )) {
                    Text(allSelected ? "Unselect all" : "Select all")
                        .font(.caption)
                }
                .toggleStyle(.checkbox)

                if !marked.isEmpty {
                    Text("\(marked.count) of \(entries.count) selected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 4)

            Table(entries) {
                TableColumn("") { e in
                    Toggle("", isOn: Binding(
                        get: { marked.contains(e.id) },
                        set: { isOn in
                            if isOn { marked.insert(e.id) } else { marked.remove(e.id) }
                        }
                    ))
                    .labelsHidden()
                    .toggleStyle(.checkbox)
                }
                .width(28)

                TableColumn("Name") { e in Text(e.name).lineLimit(1) }
                    .width(min: 220)
                TableColumn("Path") { e in
                    Text(e.path).font(.caption.monospaced()).lineLimit(1).truncationMode(.middle)
                }
                .width(min: 240)
                TableColumn("Size") { e in Text(ByteFormat.mb(e.size)).monospacedDigit() }
                    .width(80)
                TableColumn("Modified") { e in
                    Text(e.modified.formatted(date: .abbreviated, time: .omitted))
                }
                .width(110)
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
                .keyboardShortcut(.delete, modifiers: [])
            }
            .padding()
        }
    }

    private func scan() async {
        scanning = true
        let scanner = LargeFileScanner()
        let result = await scanner.scan(folders: scope.folders, minSize: Int64(minSizeMB) * 1_048_576)
        entries = result
        marked = []
        scanning = false
    }

    private func deleteSelected() async {
        let toDelete = entries.filter { marked.contains($0.id) }
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
