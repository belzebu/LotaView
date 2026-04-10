import SwiftUI

// MARK: - LotaView Design System Colors (Adaptive Light/Dark)

extension Color {
    // Backgrounds
    static let dsBackground = Color.adaptive(light: 0xf7f9fc, dark: 0x131315)
    static let dsSurface = Color.adaptive(light: 0xeceef1, dark: 0x1f1f21)
    static let dsSurfaceLow = Color.adaptive(light: 0xf2f4f7, dark: 0x1b1b1d)
    static let dsSurfaceHigh = Color.adaptive(light: 0xe6e8eb, dark: 0x2a2a2c)
    static let dsSurfaceHighest = Color.adaptive(light: 0xe0e3e6, dark: 0x353437)
    static let dsSurfaceBright = Color.adaptive(light: 0xf7f9fc, dark: 0x39393b)

    // Primary
    static let dsPrimary = Color.adaptive(light: 0x0058bc, dark: 0xaac7ff)
    static let dsPrimaryContainer = Color.adaptive(light: 0x0070eb, dark: 0x3e90ff)

    // Tertiary / Success
    static let dsTertiary = Color.adaptive(light: 0x006e1c, dark: 0x42e355)

    // Text
    static let dsOnSurface = Color.adaptive(light: 0x191c1e, dark: 0xe4e2e4)
    static let dsOnSurfaceVariant = Color.adaptive(light: 0x414755, dark: 0xc1c6d7)

    // Borders
    static let dsOutlineVariant = Color.adaptive(light: 0xc1c6d7, dark: 0x414755)

    // Error
    static let dsError = Color.adaptive(light: 0xba1a1a, dark: 0xffb4ab)

    // On-primary (text on primary-colored backgrounds)
    static let dsOnPrimary = Color.adaptive(light: 0xffffff, dark: 0x003064)

    // MARK: - Helpers

    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(light: Color(hex: light), dark: Color(hex: dark))
    }

    private init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

// MARK: - Adaptive Color Initializer

extension Color {
    init(light: Color, dark: Color) {
        #if os(iOS)
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
        #elseif os(macOS)
        self.init(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return isDark ? NSColor(dark) : NSColor(light)
        })
        #endif
    }
}

// MARK: - Reusable Styles

struct SentinelCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.dsSurfaceLow)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.dsOutlineVariant.opacity(0.15), lineWidth: 1)
            )
    }
}

extension View {
    func sentinelCard() -> some View {
        modifier(SentinelCardStyle())
    }
}
