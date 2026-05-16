import SwiftUI

struct CleanerCategorySection: View {
    let category: CleanerCategory
    let cleaners: [Cleaner]
    let sizes: [String: Int64]
    @Binding var selectedIDs: Set<String>
    @State private var expanded: Bool = true

    private var categoryTotal: Int64 {
        cleaners.reduce(into: 0) { $0 += sizes[$1.id] ?? 0 }
    }

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            VStack(spacing: 0) {
                ForEach(cleaners) { cleaner in
                    CleanerRow(
                        cleaner: cleaner,
                        size: sizes[cleaner.id],
                        selected: $selectedIDs.contains(cleaner.id)
                    )
                    Divider()
                }
            }
            .padding(.top, 4)
        } label: {
            HStack {
                Image(systemName: category.icon)
                Text(category.label).fontWeight(.semibold)
                Spacer()
                Text(ByteFormat.mb(categoryTotal))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
    }
}
