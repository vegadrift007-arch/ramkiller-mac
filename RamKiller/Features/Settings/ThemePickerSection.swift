import SwiftUI

struct ThemePickerSection: View {
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Appearance").vqEyebrow()

            HStack(spacing: 14) {
                ForEach(AppTheme.allCases) { t in
                    ThemeSwatchCard(
                        theme: t,
                        isSelected: themeManager.current == t
                    )
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            themeManager.current = t
                        }
                    }
                }
            }
        }
        .vqCard(padding: 22)
    }
}

private struct ThemeSwatchCard: View {
    let theme: AppTheme
    let isSelected: Bool

    var body: some View {
        let p = theme.palette
        return VStack(alignment: .leading, spacing: 0) {
            // Mini preview
            ZStack(alignment: .topLeading) {
                p.bg.frame(maxWidth: .infinity, minHeight: 86)
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Circle().fill(p.accent).frame(width: 6, height: 6)
                        Text("LIVE")
                            .font(.system(size: 8, weight: .bold))
                            .tracking(1)
                            .foregroundStyle(p.accent)
                    }
                    Text("78%")
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundStyle(p.ink)
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 3).fill(p.accent).frame(width: 18, height: 4)
                        RoundedRectangle(cornerRadius: 3).fill(p.warn).frame(width: 12, height: 4)
                        RoundedRectangle(cornerRadius: 3).fill(p.danger).frame(width: 8, height: 4)
                    }
                }
                .padding(12)
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(theme.label).font(Theme.headline(13)).foregroundStyle(Theme.ink)
                    Text(theme.description).font(.system(size: 10)).foregroundStyle(Theme.mute)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Theme.accent)
                        .font(.callout)
                }
            }
            .padding(10)
            .background(Theme.cardBg)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(isSelected ? Theme.accent : Theme.line, lineWidth: isSelected ? 2 : 1)
        )
    }
}
