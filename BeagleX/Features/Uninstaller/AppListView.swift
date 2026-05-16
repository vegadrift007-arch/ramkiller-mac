import SwiftUI

struct AppListView: View {
    let apps: [AppInfo]
    @Binding var selection: AppInfo.ID?
    @State private var search: String = ""

    var filtered: [AppInfo] {
        guard !search.isEmpty else { return apps }
        return apps.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").foregroundStyle(Theme.mute).font(.caption)
                TextField("Search apps", text: $search)
                    .textFieldStyle(.plain)
                    .font(Theme.bodyText)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Theme.cardBg)
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.line, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(8)

            ScrollView {
                LazyVStack(spacing: 1) {
                    ForEach(filtered) { app in
                        rowFor(app)
                            .onTapGesture { selection = app.id }
                            .contentShape(Rectangle())
                    }
                }
            }
        }
    }

    private func rowFor(_ app: AppInfo) -> some View {
        let isSelected = selection == app.id
        return HStack(spacing: 10) {
            if let img = app.icon {
                Image(nsImage: img).resizable().frame(width: 32, height: 32)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(app.name).font(Theme.bodyText).foregroundStyle(Theme.ink)
                Text(app.bundleIdentifier)
                    .font(Theme.mono(10))
                    .foregroundStyle(Theme.mute)
                    .lineLimit(1).truncationMode(.middle)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isSelected ? Theme.accent.opacity(0.12) : Color.clear)
        .overlay(alignment: .leading) {
            if isSelected {
                Rectangle().fill(Theme.accent).frame(width: 3)
            }
        }
    }
}
