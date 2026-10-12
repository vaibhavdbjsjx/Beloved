@_exported import PLBrand
import SwiftUI
#if canImport(AppKit) && !canImport(UIKit)
import AppKit
#endif

public extension Color {
    static let plCanvas = Color(PLPalette.canvas)
    static let plSurface = Color(PLPalette.surface)
    static let plSurfaceRaised = Color(PLPalette.surfaceRaised)
    static let plInk = Color(PLPalette.ink)
    static let plInkSecondary = Color(PLPalette.inkSecondary)
    static let plAccent = Color(themed: { $0.accent })
    static let plAccentSoft = Color(themed: { $0.accentSoft })
    static let plOnAccent = Color(themed: { $0.onAccent })
    static let plAccentFill = Color(themed: { $0.accentFill })
    static let plOnAccentFill = Color(themed: { $0.onAccentFill })
    static let plSage = Color(PLPalette.sage)
    static let plLine = Color(PLPalette.line)
    static let plCaution = Color(PLPalette.caution)
    static let plDestructive = Color(PLPalette.destructive)
    static let plGilt = Color(themed: { $0.gilt })

    /// A theme colour, resolved from `PLTheme.current` when drawn. Views redraw with a new
    /// theme because the app rebuilds its main hierarchy when the theme changes.
    init(themed token: @escaping @Sendable (PLTheme.Tokens) -> PLPalette.Pair) {
        #if canImport(UIKit)
        self.init(uiColor: UIColor(themed: token))
        #elseif canImport(AppKit)
        self.init(nsColor: NSColor(name: nil) { appearance in
            let pair = token(PLTheme.current.tokens)
            return appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(rgb: pair.dark) : NSColor(rgb: pair.light)
        })
        #endif
    }

    init(_ pair: PLPalette.Pair) {
        #if canImport(UIKit)
        self.init(uiColor: UIColor(pair))
        #elseif canImport(AppKit)
        self.init(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(rgb: pair.dark) : NSColor(rgb: pair.light)
        })
        #endif
    }
}

#if canImport(AppKit) && !canImport(UIKit)
extension NSColor {
    convenience init(rgb: UInt32) {
        self.init(
            srgbRed: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}
#endif
