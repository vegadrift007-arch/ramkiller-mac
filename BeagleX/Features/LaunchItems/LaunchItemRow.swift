import SwiftUI

struct LaunchItemRow: View {
    let item: LaunchItem
    let onDisable: () -> Void
    let onEnable: () -> Void
    let onDelete: () -> Void
    @State private var showDeleteConfirm = false

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading) {
                HStack(spacing: 6) {
                    Text(item.label).fontWeight(.medium)
                    if KnownDaemons.isCritical(item.label) {
                        Image(systemName: "lock.shield")
                            .foregroundStyle(.orange)
                            .help("Critical system daemon — protected")
                    } else if item.isApple {
                        Image(systemName: "apple.logo").foregroundStyle(.secondary).font(.caption)
                    }
                }
                if let p = item.program {
                    Text(p)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            Spacer()
            statusBadge
            HStack(spacing: 4) {
                if item.isDisabled {
                    Button("Enable") { onEnable() }
                        .buttonStyle(.bordered)
                } else {
                    Button("Disable") { onDisable() }
                        .buttonStyle(.bordered)
                }
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Image(systemName: "trash")
                }
                .disabled(KnownDaemons.isCritical(item.label))
            }
        }
        .padding(.vertical, 2)
        .alert("Delete \(item.label)?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { onDelete() }
        } message: {
            Text("This permanently removes the plist file. Cannot be undone.")
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        if item.isDisabled {
            Text("Disabled").font(.caption).foregroundStyle(.secondary)
        } else {
            Text("Active").font(.caption).foregroundStyle(.green)
        }
    }
}
