import SwiftUI

struct ProcessDetailView: View {
    let process: ProcessReading

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(process.name).font(.title2)
                LabeledContent("PID", value: "\(process.pid)")
                LabeledContent("User", value: process.user)
                LabeledContent("RSS", value: ByteFormat.mb(process.rssBytes))
                LabeledContent("Started", value: process.startedAt.formatted(date: .numeric, time: .standard))
                if let path = process.executablePath {
                    LabeledContent("Path", value: path)
                        .lineLimit(3)
                }
                Spacer()
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
