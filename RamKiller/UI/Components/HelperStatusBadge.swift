import SwiftUI

struct HelperStatusBadge: View {
    @ObservedObject var manager = HelperManager.shared

    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
                .font(.caption)
        }
    }

    private var color: Color {
        switch manager.status {
        case .enabled:           return .green
        case .requiresApproval:  return .yellow
        case .notRegistered:     return .red
        case .unknown:           return .gray
        }
    }

    private var label: String {
        switch manager.status {
        case .enabled:           return "Helper enabled"
        case .requiresApproval:  return "Needs approval (System Settings)"
        case .notRegistered:     return "Not installed"
        case .unknown:           return "Unknown"
        }
    }
}
