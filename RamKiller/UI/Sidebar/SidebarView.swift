import SwiftUI

struct SidebarView: View {
    @Binding var selection: SidebarItem?

    private let tools: [SidebarItem] = [.monitoring, .processes, .automation,
                                         .cacheCleaner, .largeFiles, .uninstaller, .launchItems]
    private let system: [SidebarItem] = [.settings]

    var body: some View {
        List(selection: $selection) {
            Section {
                ForEach(tools, id: \.self) { item in
                    Label(item.label, systemImage: item.icon)
                        .tag(item as SidebarItem?)
                        .listRowBackground(Color.clear)
                }
            } header: {
                Text("Tools").vqEyebrow()
            }

            Section {
                ForEach(system, id: \.self) { item in
                    Label(item.label, systemImage: item.icon)
                        .tag(item as SidebarItem?)
                        .listRowBackground(Color.clear)
                }
            } header: {
                Text("System").vqEyebrow()
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(Theme.bg2)
        .frame(minWidth: 200)
    }
}

#Preview {
    @Previewable @State var sel: SidebarItem? = .monitoring
    return SidebarView(selection: $sel)
        .frame(width: 220, height: 500)
}
