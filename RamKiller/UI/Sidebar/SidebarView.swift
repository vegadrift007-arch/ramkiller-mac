import SwiftUI

struct SidebarView: View {
    @Binding var selection: SidebarItem?

    private let tools: [SidebarItem] = [.monitoring, .processes, .automation,
                                         .cacheCleaner, .largeFiles, .uninstaller, .launchItems]
    private let system: [SidebarItem] = [.settings]

    var body: some View {
        List(selection: $selection) {
            Section("Tools") {
                ForEach(tools, id: \.self) { item in
                    Label(item.label, systemImage: item.icon)
                        .tag(item as SidebarItem?)
                }
            }
            Section("System") {
                ForEach(system, id: \.self) { item in
                    Label(item.label, systemImage: item.icon)
                        .tag(item as SidebarItem?)
                }
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
