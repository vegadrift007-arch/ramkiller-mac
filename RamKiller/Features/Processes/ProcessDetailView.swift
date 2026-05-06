import SwiftUI

struct ProcessDetailView: View {
    let process: ProcessReading

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                VStack(alignment: .leading, spacing: 6) {
                    Text("Process").vqEyebrow()
                    Text(process.name)
                        .font(Theme.display(20))
                        .foregroundStyle(Theme.ink)
                }

                // Big RSS display
                VStack(alignment: .leading, spacing: 4) {
                    Text("Resident memory").vqEyebrow()
                    Text(ByteFormat.mb(process.rssBytes))
                        .font(Theme.display(28))
                        .foregroundStyle(process.rssBytes > 500_000_000 ? Theme.warn : Theme.accent)
                        .monospacedDigit()
                }
                .vqCard()

                // Details list
                VStack(spacing: 10) {
                    detailRow("PID", value: "\(process.pid)")
                    detailRow("User", value: process.user)
                    detailRow("Started", value: process.startedAt.formatted(date: .numeric, time: .standard))
                    detailRow("Elapsed", value: elapsedString)
                    if let path = process.executablePath {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Path").vqEyebrow()
                            Text(path)
                                .font(Theme.mono(11))
                                .foregroundStyle(Theme.inkSoft)
                                .lineLimit(3)
                                .multilineTextAlignment(.leading)
                        }
                    }
                }
                .vqCard()

                Spacer()
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func detailRow(_ title: LocalizedStringKey, value: String) -> some View {
        HStack {
            Text(title).vqEyebrow()
            Spacer()
            Text(value).font(Theme.mono(12)).foregroundStyle(Theme.ink)
        }
    }

    private var elapsedString: String {
        let s = process.elapsedSeconds
        if s < 60 { return "\(s)s" }
        if s < 3600 { return "\(s / 60)m" }
        if s < 86400 { return String(format: "%dh %02dm", s / 3600, (s % 3600) / 60) }
        return String(format: "%dd %02dh", s / 86400, (s % 86400) / 3600)
    }
}
