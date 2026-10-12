import CoreGraphics

/// The Beloved mark: a dove in flight across a circle of light — the most widely shared
/// sign of peace, rising out of the pause. It belongs to no one building or tradition.
///
/// One geometry for every use: SwiftUI (`DoveShape` in PLDesign), the Screen Time shield
/// (`ShieldArt`), and the app icon (`scripts/app-icon`, compiled together with this file).
/// CoreGraphics only, so it also builds for macOS tooling. Coordinates are a 100-unit design
/// box, y down; the dove spans roughly x 10…97, y 1…61.
public enum DoveGeometry {
    /// The dove's extent in design units (used to fit it into any rect).
    static let extent = CGRect(x: 10, y: 1, width: 87, height: 60)

    /// The dove as one filled path: body and near wing, with the eye cut out.
    /// Fitted into `rect` (aspect preserved, centred).
    public static func path(in rect: CGRect) -> CGPath {
        let dove = bodyPath().union(nearWingPath()).subtracting(eyePath())
        return transformed(dove, into: rect)
    }

    /// The far wing, drawn behind the body in a softer tone.
    public static func farWingPath(in rect: CGRect) -> CGPath {
        transformed(farWingPath(), into: rect)
    }

    // MARK: - Drawing (design units, y down)

    static func bodyPath() -> CGPath {
        let p = CGMutablePath()
        p.move(to: pt(10.5, 39.4))                                                     // beak tip
        p.addCurve(to: pt(14.8, 36.8), control1: pt(11.8, 38.4), control2: pt(13.2, 37.5))  // beak
        p.addCurve(to: pt(25.2, 33.6), control1: pt(16.2, 33.2), control2: pt(21.8, 31.4))  // crown
        p.addCurve(to: pt(39, 41.2), control1: pt(28, 35.6), control2: pt(31.5, 39.2))      // nape
        p.addCurve(to: pt(78, 42), control1: pt(52, 43.6), control2: pt(66, 44.6))          // back
        p.addCurve(to: pt(94.5, 37.6), control1: pt(84, 40.6), control2: pt(89.5, 38.8))    // tail, upper edge
        p.addCurve(to: pt(93.6, 44.2), control1: pt(95.6, 40), control2: pt(95.4, 42.4))    // tail fan
        p.addCurve(to: pt(95.4, 49.6), control1: pt(95.6, 45.8), control2: pt(96.2, 47.8))
        p.addCurve(to: pt(74, 52), control1: pt(89, 49.8), control2: pt(82, 50.6))          // tail, underside
        p.addCurve(to: pt(36, 56.8), control1: pt(64, 57.5), control2: pt(48, 60.5))        // belly
        p.addCurve(to: pt(16.8, 43.6), control1: pt(28, 54.2), control2: pt(20.5, 48.6))    // breast
        p.addCurve(to: pt(10.5, 39.4), control1: pt(15.6, 41.8), control2: pt(13.2, 40.4))  // throat
        p.closeSubpath()
        return p
    }

    /// The near wing, raised, with three primary feathers at its trailing edge.
    static func nearWingPath() -> CGPath {
        let p = CGMutablePath()
        p.move(to: pt(33, 42))
        p.addCurve(to: pt(80, 1.5), control1: pt(40, 31), control2: pt(56, 13))
        p.addCurve(to: pt(72.5, 12), control1: pt(78, 6), control2: pt(75.5, 9.5))
        p.addLine(to: pt(76.5, 13.2))
        p.addCurve(to: pt(65.8, 24.2), control1: pt(73, 18.5), control2: pt(69.5, 21.5))
        p.addLine(to: pt(69.6, 25.8))
        p.addCurve(to: pt(57, 44), control1: pt(66, 32), control2: pt(62, 38.5))
        p.closeSubpath()
        return p
    }

    static func farWingPath() -> CGPath {
        let p = CGMutablePath()
        p.move(to: pt(29, 40))
        p.addCurve(to: pt(57, 4.5), control1: pt(33, 29), control2: pt(43, 15))
        p.addCurve(to: pt(52.5, 16.5), control1: pt(56, 10), control2: pt(54.5, 13.5))
        p.addLine(to: pt(55.5, 17.5))
        p.addCurve(to: pt(43, 41), control1: pt(52.5, 26), control2: pt(48.5, 34))
        p.closeSubpath()
        return p
    }

    static func eyePath() -> CGPath {
        CGPath(ellipseIn: CGRect(x: 19.75, y: 35.05, width: 1.7, height: 1.7), transform: nil)
    }

    private static func transformed(_ path: CGPath, into rect: CGRect) -> CGPath {
        let scale = min(rect.width / extent.width, rect.height / extent.height)
        var transform = CGAffineTransform(
            translationX: rect.midX - extent.midX * scale,
            y: rect.midY - extent.midY * scale
        ).scaledBy(x: scale, y: scale)
        return path.copy(using: &transform) ?? path
    }

    private static func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }
}
