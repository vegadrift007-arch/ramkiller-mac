import SwiftUI

struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String?
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .foregroundStyle(tint)
            if let sub = subtitle {
                Text(sub)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    HStack {
        StatCard(title: "Used", value: "28.3 GB", subtitle: "78%", tint: .accentColor)
        StatCard(title: "Unused", value: "7.5 GB", subtitle: "🟢 OK", tint: .green)
        StatCard(title: "Compressor", value: "6.1 GB", subtitle: nil, tint: .orange)
    }
    .padding()
    .frame(width: 800)
}
