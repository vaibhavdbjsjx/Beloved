import SwiftUI

/// Type scale — set like a well-made book.
///
/// Display and reading text use the system serif (New York) at regular/medium weights:
/// calm, literate, never shouty. Interface text uses SF Pro. Every style is a Dynamic Type
/// text style (or scales relative to one), so the whole app follows the user's text size.
/// Arabic, Devanagari and other scripts fall back to the system's script fonts.
public extension Font {
    /// Screen titles and greetings.
    static let plDisplay = Font.system(.largeTitle, design: .serif, weight: .regular)
    /// Section and card titles.
    static let plTitle = Font.system(.title2, design: .serif, weight: .medium)
    /// Smaller serif titles inside rows and cards.
    static let plTitleSmall = Font.system(.title3, design: .serif, weight: .medium)
    /// Prayer and scripture text — the reading voice.
    static let plPrayer = Font.system(.title3, design: .serif)
    /// Original script (Arabic, Devanagari, …) set large for legibility.
    static let plOriginalScript = Font.system(.title2)
    static let plTransliteration = Font.system(.body, design: .serif).italic()
    /// Quiet serif for quotations, intentions and notes.
    static let plQuote = Font.system(.title3, design: .serif).italic()
    static let plBody = Font.body
    static let plCallout = Font.callout
    static let plCaption = Font.footnote
    static let plLabel = Font.caption.weight(.semibold)
    /// Interface emphasis (button labels, row titles).
    static let plHeadline = Font.headline
    /// Tabular serif numerals for Journey figures.
    static let plNumeral = Font.system(.largeTitle, design: .serif, weight: .light).monospacedDigit()
    /// Verse numbers in the reader: small gilt serif figures.
    static let plVerseNumber = Font.system(.caption, design: .serif, weight: .semibold).monospacedDigit()
}

/// Typesetting for original-language scripture. Each script gets a size and leading that
/// leave room for its marks — Arabic harakat and pause signs, Hebrew niqqud and
/// cantillation, Devanagari matras — all scaled with Dynamic Type.
public struct PLScriptStyle: Sendable {
    public let font: Font
    public let lineSpacing: CGFloat
    public let isRightToLeft: Bool

    /// `script` is an ISO 15924 code (`Arab`, `Hebr`, `Deva`, `Grek`, `Latn`).
    public static func forScript(_ script: String) -> PLScriptStyle {
        switch script {
        case "Arab": PLScriptStyle(font: .system(.title), lineSpacing: 16, isRightToLeft: true)
        case "Hebr": PLScriptStyle(font: .system(.title2), lineSpacing: 12, isRightToLeft: true)
        case "Deva": PLScriptStyle(font: .system(.title3), lineSpacing: 10, isRightToLeft: false)
        case "Grek": PLScriptStyle(font: .system(.title3, design: .serif), lineSpacing: 8, isRightToLeft: false)
        default: PLScriptStyle(font: .plPrayer, lineSpacing: 7, isRightToLeft: false)
        }
    }
}

/// Spacing scale (points). Generous by design: whitespace is the luxury.
public enum PLSpacing {
    public static let xxs: CGFloat = 4
    public static let xs: CGFloat = 8
    public static let s: CGFloat = 12
    public static let m: CGFloat = 16
    public static let l: CGFloat = 24
    public static let xl: CGFloat = 32
    public static let xxl: CGFloat = 48
    public static let xxxl: CGFloat = 64
    /// Side margin for scrolling screens.
    public static let page: CGFloat = 24
}

public enum PLRadius {
    public static let chip: CGFloat = 10
    public static let control: CGFloat = 16
    public static let panel: CGFloat = 24
}

// MARK: - Text treatments

/// The hero line on Welcome and Today: larger than `.largeTitle`, still Dynamic Type aware.
public struct PLHeroText: ViewModifier {
    @ScaledMetric(relativeTo: .largeTitle) private var size: CGFloat = 40

    public init() {}

    public func body(content: Content) -> some View {
        content
            .font(.system(size: size, weight: .regular, design: .serif))
            .tracking(-0.4)
            .lineSpacing(2)
            .foregroundStyle(Color.plInk)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Small-caps label above a title ("SATURDAY, 10 OCTOBER", "TODAY'S MOMENT").
public struct PLEyebrowText: ViewModifier {
    let color: Color

    public init(color: Color = .plGilt) { self.color = color }

    public func body(content: Content) -> some View {
        content
            .font(.plLabel)
            // Expanded width gives the airy small-caps look without `.tracking`, which made
            // Xcode's accessibility audit report the labels as clipped (root-caused 2026-10-10:
            // the audit passes once tracking is removed).
            .fontWidth(.expanded)
            .textCase(.uppercase)
            .foregroundStyle(color)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Comfortable reading for prayer and scripture: serif, open leading, gentle measure.
public struct PLReadingText: ViewModifier {
    public init() {}

    public func body(content: Content) -> some View {
        content
            .font(.plPrayer)
            .lineSpacing(7)
            .foregroundStyle(Color.plInk)
            .fixedSize(horizontal: false, vertical: true)
    }
}

public extension View {
    func plHero() -> some View { modifier(PLHeroText()) }
    func plEyebrow(_ color: Color = .plGilt) -> some View { modifier(PLEyebrowText(color: color)) }
    func plReading() -> some View { modifier(PLReadingText()) }
}
