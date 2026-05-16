import SwiftUI

struct DesktopOverlaySection: View {
    @ObservedObject private var overlay = DesktopOverlayController.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Desktop Overlay").vqEyebrow()
            Toggle(isOn: $overlay.isEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Show stats widget on desktop").foregroundStyle(Theme.ink)
                    Text("Menu bar stats: CPU, RAM, and network speed")
                        .font(Theme.caption).foregroundStyle(Theme.mute)
                }
            }
            .toggleStyle(.switch)
        }
        .vqCard(padding: 22)
    }
}
