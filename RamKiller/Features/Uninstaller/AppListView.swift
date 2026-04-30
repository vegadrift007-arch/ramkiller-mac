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
            TextField("Search apps", text: $search)
                .textFieldStyle(.roundedBorder)
                .padding(8)
            List(selection: $selection) {
                ForEach(filtered) { app in
                    HStack {
                        if let img = app.icon {
                            Image(nsImage: img).resizable().frame(width: 28, height: 28)
                        }
                        VStack(alignment: .leading) {
                            Text(app.name)
                            Text(app.bundleIdentifier).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                        Spacer()
                        Text(ByteFormat.mb(app.bundleSize))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                    .tag(app.id as AppInfo.ID?)
                }
            }
        }
    }
}
