import SwiftUI

struct KillConfirmContext: Identifiable {
    let id = UUID()
    let process: ProcessReading
    let force: Bool
}

extension View {
    func killConfirmAlert(_ context: Binding<KillConfirmContext?>, onConfirm: @escaping (ProcessReading, Bool) -> Void) -> some View {
        alert(
            context.wrappedValue.map { "\($0.force ? "Force kill" : "Kill") \($0.process.name)?" } ?? "",
            isPresented: Binding(
                get: { context.wrappedValue != nil },
                set: { if !$0 { context.wrappedValue = nil } }
            ),
            presenting: context.wrappedValue
        ) { ctx in
            Button(ctx.force ? "Force kill" : "Kill", role: .destructive) {
                onConfirm(ctx.process, ctx.force)
                context.wrappedValue = nil
            }
            Button("Cancel", role: .cancel) {
                context.wrappedValue = nil
            }
        } message: { ctx in
            Text("PID \(ctx.process.pid) — \(ByteFormat.mb(ctx.process.rssBytes)) RSS\nUser: \(ctx.process.user)")
        }
    }
}
