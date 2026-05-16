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
                if scanning { ProgressView().controlSize(.small) }
            }.padding(.horizontal)

            ScrollView {
                if groups.isEmpty && !scanning {
                    ContentUnavailableView("No duplicates found", systemImage: "doc.on.doc")
                        .padding(.top, 40)
                }
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
        for g in result { keep[g.id] = g.entries.first?.id }
        scanning = false
    }

    private func deleteAllDuplicates() async {
        var freed: Int64 = 0
        for g in groups {
            let keepID = keep[g.id]
            for e in g.entries where e.id != keepID {
                do {
                    try FileManager.default.remove(e.url, toTrash: moveToTrash)
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
