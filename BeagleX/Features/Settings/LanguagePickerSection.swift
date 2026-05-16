import SwiftUI

struct LanguagePickerSection: View {
    @ObservedObject private var manager = LanguageManager.shared
    @State private var pendingChange: LanguageManager.Language?
    @State private var showRelaunchAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Language").vqEyebrow()

            VStack(alignment: .leading, spacing: 6) {
                Picker(selection: Binding(
                    get: { manager.selected },
                    set: { newValue in
                        if newValue != manager.selected {
                            pendingChange = newValue
                            showRelaunchAlert = true
                        }
                    }
                )) {
                    ForEach(LanguageManager.Language.allCases) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                } label: {
                    EmptyView()
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                Text("Switching language requires a restart.")
                    .font(Theme.caption)
                    .foregroundStyle(Theme.mute)
            }
        }
        .vqCard(padding: 22)
        .alert("Restart BeagleX?", isPresented: $showRelaunchAlert, presenting: pendingChange) { newLang in
            Button("Restart now", role: .destructive) {
                manager.selected = newLang
                manager.relaunch()
            }
            Button("Cancel", role: .cancel) {
                pendingChange = nil
            }
        } message: { _ in
            Text("BeagleX needs to restart to apply the new language.")
        }
    }
}
