import SwiftUI

struct LargeFilesView: View {
    @State private var tab: Tab = .large

    enum Tab: String, CaseIterable, Identifiable {
        case large, duplicates
        var id: String { rawValue }
        var label: String { self == .large ? "Large Files" : "Duplicates" }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Picker("", selection: $tab) {
                    ForEach(Tab.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 360)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            Group {
                switch tab {
                case .large:      LargeFileListView()
                case .duplicates: DuplicateListView()
                }
            }
        }
        .navigationTitle("Large Files")
    }
}
