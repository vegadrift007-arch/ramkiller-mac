import SwiftUI

struct ProcessRow: View {
    let process: ProcessReading

    var body: some View {
        HStack(spacing: 8) {
            Text(process.name)
                .lineLimit(1)
                .frame(maxWidth: 180, alignment: .leading)
            Text("\(process.pid)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(width: 64, alignment: .leading)
            Text(ByteFormat.mb(process.rssBytes))
                .monospacedDigit()
                .frame(width: 80, alignment: .trailing)
            Text(elapsed)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .trailing)
            Text(process.user)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 90, alignment: .leading)
        }
    }

    private var elapsed: String {
        let s = process.elapsedSeconds
        if s < 60 { return "\(s)s" }
        if s < 3600 { return "\(s / 60)m" }
        if s < 86400 { return String(format: "%dh", s / 3600) }
        return String(format: "%dd", s / 86400)
    }
}
