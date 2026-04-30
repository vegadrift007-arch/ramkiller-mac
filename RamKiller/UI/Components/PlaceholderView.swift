import SwiftUI

struct PlaceholderView: View {
    let title: String
    let phase: String
    let icon: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 64))
                .foregroundStyle(.tertiary)
            Text(title)
                .font(.title)
            Text("Coming in \(phase)")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    PlaceholderView(title: "Monitoring", phase: "Phase 1", icon: "memorychip")
        .frame(width: 600, height: 400)
}
