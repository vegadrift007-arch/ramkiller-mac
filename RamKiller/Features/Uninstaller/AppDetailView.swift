import SwiftUI

struct AppDetailView: View {
    let app: AppInfo
    @State private var leftovers: [Leftover] = []
    @State private var selectedLeftovers: Set<String> = []
    @State private var scanning: Bool = false
    @State private var hasFullDiskAccess: Bool = true
    @State private var moveToTrash: Bool = true
    @State private var showConfirm: Bool = false
    @State private var lastResult: UninstallerService.UninstallResult?
    @State private var bundleSize: Int64 = 0
    @State private var sizeComputing: Bool = false

    private var totalToFree: Int64 {
        let sel = leftovers.filter { selectedLeftovers.contains($0.id) }.reduce(into: Int64(0)) { $0 += $1.size }
        return bundleSize + sel
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                if SystemAppBlacklist.isProtected(app) {
                    protectedNotice
                } else {
                    leftoversSection
                    actionRow
                    if let r = lastResult { resultBanner(r) }
                }
            }
            .padding(24)
        }
        .background(Theme.bg)
        .alert("Uninstall \(app.name)?", isPresented: $showConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Uninstall", role: .destructive) { Task { await performUninstall() } }
        } message: {
            Text("This will \(moveToTrash ? "move to Trash" : "permanently delete"):\n• \(app.bundleURL.path)\n• \(selectedLeftovers.count) leftover items\nTotal ~\(ByteFormat.mb(totalToFree))")
        }
        .task(id: app.id) { await scanLeftovers() }
        .task(id: app.id) { await computeSize() }
    }

    @ViewBuilder
    private var header: some View {
        HStack(spacing: 16) {
            if let icon = app.icon {
                Image(nsImage: icon).resizable().frame(width: 72, height: 72)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(app.name)
                    .font(Theme.display(24))
                    .foregroundStyle(Theme.ink)
                Text(app.bundleIdentifier)
                    .font(Theme.mono(12))
                    .foregroundStyle(Theme.mute)
                HStack(spacing: 12) {
                    Label("v\(app.version)", systemImage: "tag")
                        .font(Theme.caption)
                        .foregroundStyle(Theme.inkSoft)
                    if sizeComputing {
                        HStack(spacing: 4) {
                            ProgressView().controlSize(.mini)
                            Text("Sizing…").font(Theme.caption).foregroundStyle(Theme.mute)
                        }
                    } else if bundleSize > 0 {
                        Label(ByteFormat.mb(bundleSize), systemImage: "internaldrive")
                            .font(Theme.caption)
                            .foregroundStyle(Theme.inkSoft)
                    }
                }
                .padding(.top, 4)
                Text(app.bundleURL.path)
                    .font(Theme.mono(11))
                    .foregroundStyle(Theme.mute)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.top, 2)
            }
            Spacer()
        }
        .vqCard(padding: 22)
    }

    @ViewBuilder
    private var protectedNotice: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.shield.fill").foregroundStyle(Theme.warn).font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text("Protected").font(Theme.headline()).foregroundStyle(Theme.ink)
                Text("System app — cannot be uninstalled")
                    .font(Theme.caption).foregroundStyle(Theme.inkSoft)
            }
            Spacer()
        }
        .padding(16)
        .background(Theme.warn.opacity(0.1))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.warn.opacity(0.3), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var leftoversSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Leftovers").vqEyebrow()
                Spacer()
                if scanning { ProgressView().controlSize(.small) }
                Button("Rescan") { Task { await scanLeftovers() } }
                    .buttonStyle(.borderless)
                    .foregroundStyle(Theme.accent)
                    .font(Theme.caption)
            }
            if !hasFullDiskAccess && !scanning {
                tccWarning
            }
            if leftovers.isEmpty && !scanning {
                Text(hasFullDiskAccess ? "No leftovers found." : "Scan may be incomplete — see warning above.")
                    .foregroundStyle(Theme.mute)
                    .padding(.vertical, 12)
            } else if !leftovers.isEmpty {
                Toggle(isOn: $selectedLeftovers.selectAll(of: leftovers.map { $0.id })) {
                    Text("Select all (\(leftovers.count))")
                        .font(Theme.caption)
                        .foregroundStyle(Theme.inkSoft)
                }
                .toggleStyle(.checkbox)

                VStack(spacing: 0) {
                    ForEach(leftovers) { l in
                        leftoverRow(l)
                        if l.id != leftovers.last?.id {
                            Divider().background(Theme.line)
                        }
                    }
                }
                .vqCard(padding: 0)
            }
        }
    }

    private var tccWarning: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.shield.fill")
                .foregroundStyle(Theme.warn)
                .font(.title3)
            VStack(alignment: .leading, spacing: 4) {
                Text("Limited file access").font(Theme.headline()).foregroundStyle(Theme.ink)
                Text("RamKiller can't read parts of ~/Library, so some leftovers may be missed. Grant Full Disk Access for best results.")
                    .font(Theme.caption)
                    .foregroundStyle(Theme.inkSoft)
                Button("Open System Settings") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.borderless)
                .foregroundStyle(Theme.accent)
                .font(Theme.caption)
                .padding(.top, 2)
            }
            Spacer()
        }
        .padding(12)
        .background(Theme.warn.opacity(0.1))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.warn.opacity(0.3), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func leftoverRow(_ l: Leftover) -> some View {
        HStack(spacing: 10) {
            Toggle("", isOn: $selectedLeftovers.contains(l.id))
                .labelsHidden().toggleStyle(.checkbox)
            Image(systemName: l.kind.icon).foregroundStyle(Theme.inkSoft).frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(l.path).font(Theme.mono(11)).foregroundStyle(Theme.inkSoft)
                    .lineLimit(1).truncationMode(.middle)
                Text(l.kind.label).font(Theme.eyebrow).foregroundStyle(Theme.mute)
            }
            Spacer()
            Text(ByteFormat.mb(l.size))
                .font(Theme.mono(12))
                .foregroundStyle(Theme.inkSoft)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var actionRow: some View {
        HStack {
            Toggle("Move to Trash", isOn: $moveToTrash)
                .toggleStyle(.checkbox)
                .foregroundStyle(Theme.inkSoft)
            Spacer()
            Button {
                showConfirm = true
            } label: {
                Label("Uninstall \(ByteFormat.mb(totalToFree))", systemImage: "trash.fill")
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.danger)
            .keyboardShortcut(.defaultAction)
        }
    }

    private func resultBanner(_ r: UninstallerService.UninstallResult) -> some View {
        let ok = r.errors.isEmpty
        let tint: Color = ok ? Theme.accent : Theme.danger
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: ok ? "checkmark.circle.fill" : "exclamationmark.octagon.fill")
                    .foregroundStyle(tint)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text(ok ? "Uninstalled \(r.appName)" : "Uninstall had \(r.errors.count) error\(r.errors.count > 1 ? "s" : "")")
                        .font(Theme.headline(15))
                    Text("Freed \(ByteFormat.mb(r.bytesFreed))")
                        .font(Theme.caption)
                        .foregroundStyle(Theme.inkSoft)
                }
                Spacer()
                Button("Dismiss") { lastResult = nil }
                    .buttonStyle(.borderless)
                    .foregroundStyle(Theme.inkSoft)
                    .font(Theme.caption)
            }
            if !r.errors.isEmpty {
                Divider().background(Theme.line)
                ForEach(r.errors, id: \.self) { e in
                    HStack(alignment: .top, spacing: 6) {
                        Text("•").foregroundStyle(Theme.danger)
                        Text(e)
                            .font(Theme.caption.monospaced())
                            .foregroundStyle(Theme.danger)
                            .textSelection(.enabled)
                    }
                }
            }
        }
        .padding(14)
        .background(tint.opacity(0.08))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(tint.opacity(0.3), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func scanLeftovers() async {
        scanning = true
        let result = await LeftoverScanner().scanFull(for: app)
        leftovers = result.leftovers
        hasFullDiskAccess = result.hasFullDiskAccess
        selectedLeftovers = Set(leftovers.map { $0.id })
        scanning = false
    }

    private func computeSize() async {
        sizeComputing = true
        let url = app.bundleURL
        let size = await Task.detached(priority: .utility) {
            AppDiscoveryService().bundleSize(at: url)
        }.value
        bundleSize = size
        sizeComputing = false
    }

    private func performUninstall() async {
        let chosen = leftovers.filter { selectedLeftovers.contains($0.id) }
        let appWithSize = AppInfo(
            id: app.id, bundleIdentifier: app.bundleIdentifier, name: app.name,
            version: app.version, bundleURL: app.bundleURL,
            bundleSize: bundleSize, icon: app.icon
        )
        let result = await UninstallerService().uninstall(app: appWithSize, leftovers: chosen, moveToTrash: moveToTrash)
        lastResult = result
    }
}
