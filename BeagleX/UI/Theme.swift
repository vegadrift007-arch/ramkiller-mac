import SwiftUI
import Combine

// MARK: - Color Palette

public struct ColorPalette {
    let bg: Color
    let bg2: Color
    let cardBg: Color
    let cardBgHover: Color
    let line: Color
    let lineStrong: Color
    let ink: Color
    let inkSoft: Color
    let mute: Color
    let accent: Color
    let accentSoft: Color
    let positive: Color    // semantic green (healthy)
    let warn: Color
    let danger: Color
    let purple: Color
    let isLight: Bool      // for system colorScheme
}

// MARK: - Themes

public enum AppTheme: String, CaseIterable, Identifiable {
    case midnight
    case bloom

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .midnight: return String(localized: "Midnight")
        case .bloom:    return String(localized: "Bloom")
        }
    }

    public var description: String {
        switch self {
        case .midnight: return String(localized: "Dark navy + electric green")
        case .bloom:    return String(localized: "Pastel pink + soft purple")
        }
    }

    public var palette: ColorPalette {
        switch self {
        case .midnight:
            return ColorPalette(
                bg: Color(hex: 0x0A0F1C),
                bg2: Color(hex: 0x10162A),
                cardBg: Color.white.opacity(0.04),
                cardBgHover: Color.white.opacity(0.06),
                line: Color.white.opacity(0.08),
                lineStrong: Color.white.opacity(0.14),
                ink: Color(hex: 0xF5F5F7),
                inkSoft: Color(hex: 0xC8CCD6),
                mute: Color(hex: 0x6E7484),
                accent: Color(hex: 0x00C805),
                accentSoft: Color(red: 0/255, green: 200/255, blue: 5/255, opacity: 0.16),
                positive: Color(hex: 0x00C805),
                warn: Color(hex: 0xFFB02E),
                danger: Color(hex: 0xFF453A),
                purple: Color(hex: 0x8B5CF6),
                isLight: false
            )
        case .bloom:
            return ColorPalette(
                bg: Color(hex: 0xFCE9F3),
                bg2: Color(hex: 0xEFE0F8),
                cardBg: Color.white,
                cardBgHover: Color(hex: 0xFFF6FB),
                line: Color(red: 26/255, green: 14/255, blue: 46/255, opacity: 0.08),
                lineStrong: Color(red: 26/255, green: 14/255, blue: 46/255, opacity: 0.16),
                ink: Color(hex: 0x1A0E2E),
                inkSoft: Color(hex: 0x4A3A66),
                mute: Color(hex: 0x7A6E8E),
                accent: Color(hex: 0xFF2D87),
                accentSoft: Color(red: 255/255, green: 45/255, blue: 135/255, opacity: 0.12),
                positive: Color(hex: 0x0EAB6E),
                warn: Color(hex: 0xFF9700),
                danger: Color(hex: 0xE81879),
                purple: Color(hex: 0x9D6FFE),
                isLight: true
            )
        }
    }
}

// MARK: - Theme Manager (observable)

@MainActor
public final class ThemeManager: ObservableObject {
    public static let shared = ThemeManager()

    @Published public var current: AppTheme {
        didSet { UserDefaults.standard.set(current.rawValue, forKey: "theme") }
    }

    private init() {
        let raw = UserDefaults.standard.string(forKey: "theme") ?? AppTheme.midnight.rawValue
        self.current = AppTheme(rawValue: raw) ?? .midnight
    }
}

// MARK: - Static accessors (re-evaluate on each call so static reads pick up new theme after view re-render)

public enum Theme {
    static var palette: ColorPalette { ThemeManager.shared.current.palette }

    static var bg: Color           { palette.bg }
    static var bg2: Color          { palette.bg2 }
    static var cardBg: Color       { palette.cardBg }
    static var cardBgHover: Color  { palette.cardBgHover }
    static var line: Color         { palette.line }
    static var lineStrong: Color   { palette.lineStrong }
    static var ink: Color          { palette.ink }
    static var inkSoft: Color      { palette.inkSoft }
    static var mute: Color         { palette.mute }
    static var accent: Color       { palette.accent }
    static var accentSoft: Color   { palette.accentSoft }
    static var positive: Color     { palette.positive }
    static var warn: Color         { palette.warn }
    static var danger: Color       { palette.danger }
    static var purple: Color       { palette.purple }

    // Fonts (theme-agnostic)
    static func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: .heavy, design: .rounded)
    }
    static func headline(_ size: CGFloat = 17) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }
    static func mono(_ size: CGFloat = 13) -> Font {
        .system(size: size, weight: .medium, design: .monospaced)
    }
    static let eyebrow: Font = .system(size: 10, weight: .bold, design: .default)
    static let bodyText: Font = .system(size: 14, weight: .regular)
    static let caption: Font = .system(size: 12, weight: .regular)
}

// MARK: - Color hex helper

extension Color {
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1.0)
    }
}

// MARK: - Modifiers

extension View {
    func vqCard(padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .background(Theme.cardBg)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Theme.line, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    func vqEyebrow(color: Color? = nil) -> some View {
        self
            .font(Theme.eyebrow)
            .tracking(1.2)
            .textCase(.uppercase)
            .foregroundStyle(color ?? Theme.mute)
    }
}

struct VQTag: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(Theme.eyebrow)
            .tracking(1.0)
            .textCase(.uppercase)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
            .overlay(
                Capsule().strokeBorder(color.opacity(0.3), lineWidth: 1)
            )
    }
}

struct VQPulseDot: View {
    let color: Color
    @State private var phase: CGFloat = 0

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 7, height: 7)
            .overlay(
                Circle()
                    .stroke(color.opacity(0.5 - 0.5 * phase), lineWidth: 2)
                    .scaleEffect(1 + phase * 1.4)
            )
            .onAppear {
                withAnimation(.easeOut(duration: 1.6).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}
