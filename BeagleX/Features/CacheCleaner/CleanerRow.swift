import SwiftUI

struct CleanerRow: View {
    let cleaner: Cleaner
    let size: Int64?
    @Binding var selected: Bool
    @State private var showDetails: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Toggle("", isOn: $selected).labelsHidden()
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(cleaner.name).fontWeight(.medium)
                        badge
                    }
                    Text(cleaner.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(showDetails ? nil : 1)
                }
                Spacer()
                Text(sizeLabel)
                    .monospacedDigit()
                    .frame(width: 80, alignment: .trailing)
                Button {
                    showDetails.toggle()
                } label: {
                    Image(systemName: showDetails ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
            }
            if showDetails {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(cleaner.paths, id: \.self) { p in
                        Text(p).font(.caption.monospaced()).foregroundStyle(.tertiary).lineLimit(1).truncationMode(.middle)
                    }
                }
                .padding(.leading, 28)
            }
        }
        .padding(.vertical, 4)
    }

    private var sizeLabel: String {
        guard let s = size else { return "—" }
        if s == 0 { return "0 B" }
        if s < 1024 * 1024 { return "\(s / 1024) KB" }
        return ByteFormat.mb(s)
    }

    @ViewBuilder
    private var badge: some View {
        switch cleaner.safety {
        case .safe:    EmptyView()
        case .caution: Text("⚠️").font(.caption)
        case .risky:   Text("🔴").font(.caption)
        }
    }
}
