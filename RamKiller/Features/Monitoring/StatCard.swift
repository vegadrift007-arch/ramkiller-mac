import SwiftUI

struct StatCard: View {
    let title: LocalizedStringKey
    let value: String
    let subtitle: String?
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).vqEyebrow()

            Text(value)
                .font(Theme.display(28))
                .foregroundStyle(tint)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            if let sub = subtitle {
                Text(sub)
                    .font(Theme.caption)
                    .foregroundStyle(Theme.inkSoft)
            } else {
                Text(" ").font(Theme.caption)         // spacer to keep heights aligned
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .vqCard(padding: 18)
    }
}
