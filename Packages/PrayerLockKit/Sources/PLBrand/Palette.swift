import Synchronization
#if canImport(UIKit)
import UIKit
#endif

/// Each faith gets its own colour, set on the same vellum paper and printer's ink so reading
/// stays consistent: royal lapis and gold for Christians (also the brand), emerald and gold
/// for Muslims, saffron and marigold for Hindus. Every pairing passes WCAG AA in light and
/// dark (`PaletteContrastTests` checks all themes).
public enum PLTheme: String, CaseIterable, Sendable {
    /// Royal lapis and gold — Christianity, and the brand default (onboarding, the shield).
    case lapis
    /// Deep emerald and gold — Islam.
    case emerald
    /// Saffron, vermilion and marigold — Hinduism.
    case saffron

    public struct Tokens: Sendable {
        public let accent: PLPalette.Pair
        public let onAccent: PLPalette.Pair
        public let accentFill: PLPalette.Pair
        public let onAccentFill: PLPalette.Pair
        public let accentSoft: PLPalette.Pair
        public let gilt: PLPalette.Pair
    }

    public var tokens: Tokens {
        switch self {
        case .lapis:
            Tokens(accent: .init(light: 0x243B7F, dark: 0xA9BBEE), onAccent: .init(light: 0xFFFFFF, dark: 0x0F1014),
                   accentFill: .init(light: 0x243B7F, dark: 0x4462B8), onAccentFill: .init(light: 0xFFFFFF, dark: 0xF1EBDD),
                   accentSoft: .init(light: 0xE4E8F3, dark: 0x1E2742), gilt: .init(light: 0x7A5A14, dark: 0xD9B76E))
        case .emerald:
            Tokens(accent: .init(light: 0x1B5E4A, dark: 0x8ED6B9), onAccent: .init(light: 0xFFFFFF, dark: 0x0F1014),
                   accentFill: .init(light: 0x1B5E4A, dark: 0x2A705A), onAccentFill: .init(light: 0xFFFFFF, dark: 0xF1EBDD),
                   accentSoft: .init(light: 0xE0EEE7, dark: 0x16302A), gilt: .init(light: 0x7A5A14, dark: 0xD9B76E))
        case .saffron:
            Tokens(accent: .init(light: 0x9A3412, dark: 0xFFB38A), onAccent: .init(light: 0xFFFFFF, dark: 0x0F1014),
                   accentFill: .init(light: 0xA83A14, dark: 0xB04A1C), onAccentFill: .init(light: 0xFFFFFF, dark: 0xF6EEE2),
                   accentSoft: .init(light: 0xF7E6DA, dark: 0x3A2218), gilt: .init(light: 0x8A5300, dark: 0xF0B860))
        }
    }

    /// The theme the app draws with. The app sets it from the user's faith; the Screen Time
    /// extensions never see the faith and always use the brand default.
    public static var current: PLTheme {
        get { storage.withLock { $0 } }
        set { storage.withLock { $0 = newValue } }
    }

    private static let storage = Mutex<PLTheme>(.lapis)
}

/// The Beloved palette — "Threshold": vellum paper, printer's ink, lapis and gilt.
///
/// Lapis lazuli and gold leaf are sacred pigments shared across the traditions Beloved
/// serves (icons and manuscripts, Islamic illumination, Hindu painting), so the palette
/// carries meaning without belonging to any one faith. Lapis marks actions; gilt is used
/// sparingly for ornament and small labels. Dark appearance is designed as a night vigil:
/// warm ink, parchment text, candle-gold accents — not an inversion.
///
/// Every text token meets WCAG AA (4.5:1) on every background in both appearances —
/// enforced by `PaletteContrastTests`. Change a value only with that test green.
///
/// This module has no dependencies so the sandboxed Shield Configuration extension can
/// use the brand colors without linking SwiftUI or any content resources.
public enum PLPalette {
    public struct Pair: Sendable {
        public let light: UInt32
        public let dark: UInt32

        public init(light: UInt32, dark: UInt32) {
            self.light = light
            self.dark = dark
        }
    }

    // Backgrounds
    /// Vellum — the page every screen is printed on.
    public static let canvas = Pair(light: 0xF4EFE6, dark: 0x0F1014)
    /// Paper — cards and grouped rows, a shade lighter than the page (never stark white).
    public static let surface = Pair(light: 0xFBF8F2, dark: 0x17181E)
    /// Pressed/inset paper, disabled controls, empty marks.
    public static let surfaceRaised = Pair(light: 0xECE5D7, dark: 0x21232B)
    /// The theme's wash behind selected or highlighted content.
    public static var accentSoft: Pair { PLTheme.current.tokens.accentSoft }

    // Text and marks
    public static let ink = Pair(light: 0x1D1B18, dark: 0xEDE6D8)
    public static let inkSecondary = Pair(light: 0x5C564C, dark: 0xADA698)
    // Theme colours (see `PLTheme`): read at the moment they're drawn.
    /// Primary actions, selection, links.
    public static var accent: Pair { PLTheme.current.tokens.accent }
    public static var onAccent: Pair { PLTheme.current.tokens.onAccent }
    /// The accent as a *fill* (primary buttons, selected chips). At night it stays deep, with
    /// parchment lettering, rather than a pale glowing slab; `accent` stays readable as text.
    public static var accentFill: Pair { PLTheme.current.tokens.accentFill }
    public static var onAccentFill: Pair { PLTheme.current.tokens.onAccentFill }
    /// Gilt — eyebrow labels, ornaments, the dove. Use sparingly.
    public static var gilt: Pair { PLTheme.current.tokens.gilt }
    /// Practiced days in Journey (non-text; 3:1 is the requirement).
    public static let sage = Pair(light: 0x4A7660, dark: 0x8DC2A4)
    /// Hairlines and borders (decorative, never the only signal).
    public static let line = Pair(light: 0xDCD3C2, dark: 0x2C2E36)
    public static let caution = Pair(light: 0x8A5A10, dark: 0xE2B66B)
    /// Destructive actions. iOS's system red is ~3.6:1 on white (below WCAG AA for text).
    public static let destructive = Pair(light: 0xA8231A, dark: 0xFF8A80)

    // Time-of-day light (decorative washes behind headers; text contrast is unaffected
    // at the opacities used — see `PLLight`).
    public static let dawnLight = Pair(light: 0xF2C9B0, dark: 0x5A3A3E)
    public static let dayLight = Pair(light: 0xF3E2B3, dark: 0x4A4230)
    public static let duskLight = Pair(light: 0xE9B98A, dark: 0x5A3B26)
    public static let nightLight = Pair(light: 0xB9C4E8, dark: 0x24305A)

}

#if canImport(UIKit)
public extension UIColor {
    /// Dynamic color that follows light/dark appearance.
    convenience init(_ pair: PLPalette.Pair) {
        self.init { traits in
            UIColor(rgb: traits.userInterfaceStyle == .dark ? pair.dark : pair.light)
        }
    }

    /// Dynamic color for a theme token, read from `PLTheme.current` each time it's resolved.
    convenience init(themed token: @escaping @Sendable (PLTheme.Tokens) -> PLPalette.Pair) {
        self.init { traits in
            let pair = token(PLTheme.current.tokens)
            return UIColor(rgb: traits.userInterfaceStyle == .dark ? pair.dark : pair.light)
        }
    }

    convenience init(rgb: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: alpha
        )
    }
}
#endif

#if canImport(UIKit)
/// Artwork for the system shield (ShieldConfiguration allows only an icon, text, colours
/// and two buttons). Drawn with UIKit so the sandboxed extension needs no assets or SwiftUI.
public enum ShieldArt {
    /// A mid gilt that keeps ≥ 3:1 (non-text) on both the light and dark shield background.
    static let mark = UIColor(rgb: 0xA27C2C)

    /// The Beloved dove in gilt, inside a fine circle of light.
    public static func doveIcon(size: CGSize = CGSize(width: 72, height: 72)) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            let rect = CGRect(origin: .zero, size: size).insetBy(dx: 1.5, dy: 1.5)
            let ring = UIBezierPath(ovalIn: rect)
            ring.lineWidth = 1.5
            mark.withAlphaComponent(0.55).setStroke()
            ring.stroke()
            let doveRect = rect.insetBy(dx: rect.width * 0.14, dy: rect.height * 0.22)
            let cg = context.cgContext
            cg.addPath(DoveGeometry.farWingPath(in: doveRect))
            cg.setFillColor(mark.withAlphaComponent(0.5).cgColor)
            cg.fillPath()
            cg.addPath(DoveGeometry.path(in: doveRect))
            cg.setFillColor(mark.cgColor)
            cg.fillPath()
        }
        return image.withRenderingMode(.alwaysOriginal)
    }
}
#endif
