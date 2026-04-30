import SwiftUI

struct AppDetailView: View {
    let app: AppInfo
    @State private var leftovers: [Leftover] = []
    @State private var selectedLeftovers: Set<String> = []
    @State private var scanning: Bool = false
    @State private var moveToTrash: Bool = true
    @State private var showConfirm: Bool = false
    @State private var lastResult: UninstallerService.UninstallResult?

    private var totalToFree: Int64 {
        let sel = leftovers.filter { selectedLeftovers.contains($0.id) }.reduce(into: Int64(0)) { $0 += $1.size }
        return app.bundleSize + sel
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                header
                if SystemAppBlacklist.isProtected(app) {
                    protectedNotice
                } else {
                    leftoversSection
                    actionRow
                    if let r = lastResult { resultBanner(r) }
                }
            }
            .padding(16)
        }
        .alert("Uninstall \(app.name)?", isPresented: $showConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Uninstall", role: .destructive) { Task { await performUninstall() } }
        } message: {
            Text("This will \(moveToTrash ? "move to Trash" : "permanently delete"):\n• \(app.bundleURL.path)\n• \(selectedLeftovers.count) leftover items\nTotal ~\(ByteFormat.mb(totalToFree))")
        }
        .task(id: app.id) { await scanLeftovers() }
    }

    @ViewBuilder
    private var header: some View {
        HStack(spacing: 12) {
            if let icon = app.icon {
                Image(nsImage: icon).resizable().frame(width: 64, height: 64)
            }
            VStack(alignment: .leading) {
                Text(app.name).font(.title2)
                Text(app.bundleIdentifier).foregroundStyle(.secondary)
                Text("Version \(app.version) — \(ByteFormat.mb(app.bundleSize))").font(.caption)
                Text(app.bundleURL.path).font(.caption.monospaced()).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
            }
            Spacer()
        }
    }

    @ViewBuilder
    private var protectedNotice: some View {
        HStack {
            Image(systemName: "lock.shield").foregroundStyle(.orange)
            Text("System app — cannot be uninstalled")
        }
        .padding(8)
        .background(Color.orange.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var leftoversSection: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Leftovers").font(.headline)
                Spacer()
                if scanning { ProgressView().controlSize(.small) }
                Button("Rescan") { Task { await scanLeftovers() } }
            }
            if leftovers.isEmpty {
                Text("No leftovers found.")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                Toggle(isOn: Binding(
                    get: { selectedLeftovers.count == leftovers.count && !leftovers.isEmpty },
                    set: { isOn in
                        selectedLeftovers = isOn ? Set(leftovers.map { $0.id }) : []
                    }
                )) {
                    Text("Select all leftovers (\(leftovers.count) items)")
                        .font(.caption)
                }
                .toggleStyle(.checkbox)

                ForEach(leftovers) { l in
                    HStack {
                        Toggle("", isOn: Binding(
                            get: { selectedLeftovers.contains(l.id) },
                            set: { v in
                                if v { selectedLeftovers.insert(l.id) } else { selectedLeftovers.remove(l.id) }
                            }
                        )).labelsHidden().toggleStyle(.checkbox)
                        Image(systemName: l.kind.icon)
                        VStack(alignment: .leading) {
                            Text(l.path).font(.caption.monospaced()).lineLimit(1).truncationMode(.middle)
                            Text(l.kind.label).font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(ByteFormat.mb(l.size)).monospacedDigit().foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private var actionRow: some View {
        HStack {
            Toggle("Move to Trash", isOn: $moveToTrash)
            Spacer()
            Button {
                showConfirm = true
            } label: {
                Label("Uninstall (\(ByteFormat.mb(totalToFree)))", systemImage: "trash")
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
        }
        .padding(.top, 8)
    }

    private func resultBanner(_ r: UninstallerService.UninstallResult) -> some View {
        VStack(alignment: .leading) {
            HStack {
                Image(systemName: r.errors.isEmpty ? "checkmark.circle" : "exclamationmark.triangle")
                    .foregroundStyle(r.errors.isEmpty ? .green : .orange)
                Text("Uninstalled \(r.appName), freed \(ByteFormat.mb(r.bytesFreed))")
                Spacer()
                Button("Dismiss") { lastResult = nil }
            }
            ForEach(r.errors, id: \.self) { e in
                Text(e).font(.caption).foregroundStyle(.red)
            }
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func scanLeftovers() async {
        scanning = true
        leftovers = await LeftoverScanner().scan(for: app)
        selectedLeftovers = Set(leftovers.map { $0.id })  // default: select all
        scanning = false
    }

    private func performUninstall() async {
        let chosen = leftovers.filter { selectedLeftovers.contains($0.id) }
        let result = await UninstallerService().uninstall(app: app, leftovers: chosen, moveToTrash: moveToTrash)
        lastResult = result
    }
}
