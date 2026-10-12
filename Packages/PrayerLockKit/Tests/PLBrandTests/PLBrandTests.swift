import Foundation
import Testing
@testable import PLBrand

/// WCAG 2.x contrast for every palette pairing the app uses, in light and dark appearance.
/// Text needs 4.5:1 (AA, normal text); non-text graphics (the Journey week dots) need 3:1.
@Suite(.serialized) struct PaletteContrastTests {
    private static func luminance(_ rgb: UInt32) -> Double {
        func channel(_ shift: UInt32) -> Double {
            let value = Double((rgb >> shift) & 0xFF) / 255
            return value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(16) + 0.7152 * channel(8) + 0.0722 * channel(0)
    }

    static func ratio(_ a: UInt32, _ b: UInt32) -> Double {
        let (x, y) = (luminance(a), luminance(b))
        return (max(x, y) + 0.05) / (min(x, y) + 0.05)
    }

    private static func backgrounds(_ theme: PLTheme) -> [(String, PLPalette.Pair)] {
        [("canvas", PLPalette.canvas), ("surface", PLPalette.surface),
         ("surfaceRaised", PLPalette.surfaceRaised), ("accentSoft", theme.tokens.accentSoft)]
    }

    private static func textTokens(_ theme: PLTheme) -> [(String, PLPalette.Pair)] {
        [("ink", PLPalette.ink), ("inkSecondary", PLPalette.inkSecondary),
         ("accent", theme.tokens.accent), ("caution", PLPalette.caution),
         ("destructive", PLPalette.destructive), ("gilt", theme.tokens.gilt)]
    }

    @Test(arguments: PLTheme.allCases)
    func textTokensMeetAAOnEveryBackground(_ theme: PLTheme) {
        for token in Self.textTokens(theme) {
            for (name, background) in Self.backgrounds(theme) {
                let light = Self.ratio(token.1.light, background.light)
                let dark = Self.ratio(token.1.dark, background.dark)
                #expect(light >= 4.5, "\(theme) \(token.0) on \(name), light: \(light)")
                #expect(dark >= 4.5, "\(theme) \(token.0) on \(name), dark: \(dark)")
            }
        }
    }

    @Test(arguments: PLTheme.allCases)
    func textOnAccentButtonsMeetsAA(_ theme: PLTheme) {
        let t = theme.tokens
        #expect(Self.ratio(t.onAccent.light, t.accent.light) >= 4.5)
        #expect(Self.ratio(t.onAccent.dark, t.accent.dark) >= 4.5)
    }

    @Test(arguments: PLTheme.allCases)
    func lettersOnFillsMeetAA(_ theme: PLTheme) {
        let t = theme.tokens
        #expect(Self.ratio(t.onAccentFill.light, t.accentFill.light) >= 4.5)
        #expect(Self.ratio(t.onAccentFill.dark, t.accentFill.dark) >= 4.5)
    }

    /// WCAG 1.4.11: a filled control must stand out (3:1) from the page and from paper.
    @Test(arguments: PLTheme.allCases)
    func fillsStandOutFromTheirBackgrounds(_ theme: PLTheme) {
        for background in [PLPalette.canvas, PLPalette.surface] {
            #expect(Self.ratio(theme.tokens.accentFill.light, background.light) >= 3)
            #expect(Self.ratio(theme.tokens.accentFill.dark, background.dark) >= 3)
        }
    }

    @Test func paletteReadsTheCurrentTheme() {
        let saved = PLTheme.current
        defer { PLTheme.current = saved }
        PLTheme.current = .emerald
        #expect(PLPalette.accent.light == PLTheme.emerald.tokens.accent.light)
        PLTheme.current = .lapis
        #expect(PLPalette.accent.light == 0x243B7F)
    }

    @Test func journeyDotsMeetNonTextContrast() {
        for background in [PLPalette.canvas, PLPalette.surface, PLPalette.surfaceRaised] {
            #expect(Self.ratio(PLPalette.sage.light, background.light) >= 3)
            #expect(Self.ratio(PLPalette.sage.dark, background.dark) >= 3)
        }
    }

    @Test func ratioMatchesKnownValues() {
        #expect(abs(Self.ratio(0x000000, 0xFFFFFF) - 21) < 0.01)
        #expect(abs(Self.ratio(0x777777, 0xFFFFFF) - 4.48) < 0.01)
    }
}
