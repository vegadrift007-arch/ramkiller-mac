import SwiftUI

struct SidebarView: View {
    @Binding var selection: SidebarItem?

    var body: some View {
        List(selection: $selection) {
            Section("Tools") {
                ForEach([SidebarItem.monitoring, .processes, .automation,
                         .cacheCleaner, .largeFiles, .uninstaller, .launchItems], id: \.self) { item in
                    Label(item.label, systemImage: item.icon)
                        .tag(Optional(item))
                }
            }
            Section {
                Label(SidebarItem.settings.label, systemImage: SidebarItem.settings.icon)
                    .tag(Optional(SidebarItem.settings))
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 180)
        .navigationTitle("RamKiller")
    }
}

#Preview {
    @Previewable @State var sel: SidebarItem? = .monitoring
    return SidebarView(selection: $sel)
        .frame(width: 200, height: 500)
}
