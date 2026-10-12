import PLBrand
import PLContent
import SwiftUI

// A pause is a threshold — the moment between reaching for something and choosing it.
// Beloved draws it as a circle of light (sun, moon, lamp-glow, halo — shared by every
// tradition and owned by none) and signs it with a dove in flight across that light, as in
// the app icon. No buildings: an arch reads as one faith's architecture.

/// The Beloved dove (body and near wing; see `DoveGeometry`), as a SwiftUI shape.
public struct DoveShape: Shape {
    public init() {}
    public func path(in rect: CGRect) -> Path { Path(DoveGeometry.path(in: rect)) }
}

/// The dove's far wing, drawn behind `DoveShape` in a softer tone (same frame).
public struct DoveFarWingShape: Shape {
    public init() {}
    public func path(in rect: CGRect) -> Path { Path(DoveGeometry.farWingPath(in: rect)) }
}

/// The dove with its far wing, in one colour (the far wing softened).
public struct DoveMark: View {
    let color: Color
    let farWing: Color?

    /// `farWing`: the far wing's colour (defaults to a softened `color`).
    public init(color: Color = .plGilt, farWing: Color? = nil) {
        self.color = color
        self.farWing = farWing
    }

    public var body: some View {
        ZStack {
            DoveFarWingShape().fill(farWing ?? color.opacity(0.45))
            DoveShape().fill(color)
        }
        .accessibilityHidden(true)
    }
}

/// The light of a time of day, used behind headers and inside the threshold.
public enum PLLight {
    public static func color(for time: TimeOfDay) -> Color {
        switch time {
        case .morning: Color(PLPalette.dawnLight)
        case .midday: Color(PLPalette.dayLight)
        case .evening: Color(PLPalette.duskLight)
        case .night: Color(PLPalette.nightLight)
        }
    }

    public static func current(calendar: Calendar = .autoupdatingCurrent, date: Date = .now) -> Color {
        color(for: TimeOfDay(date: date, calendar: calendar))
    }
}

/// A soft wash of the hour's light across the top of a screen. Decorative; text contrast
/// stays above WCAG AA at these opacities (checked against every light and both modes).
public struct PLLightWash: View {
    @Environment(\.colorScheme) private var colorScheme
    let light: Color
    let height: CGFloat

    public init(light: Color = PLLight.current(), height: CGFloat = 420) {
        self.light = light
        self.height = height
    }

    public var body: some View {
        RadialGradient(
            colors: [light.opacity(colorScheme == .dark ? 0.5 : 0.34), light.opacity(0)],
            center: UnitPoint(x: 0.25, y: 0),
            startRadius: 0,
            endRadius: height
        )
        .frame(height: height)
        .frame(maxWidth: .infinity, alignment: .top)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// The pause: a circle of paper with a double gilt rule and a light that breathes (four
/// seconds in, four out). When the pause is complete (`.open`) the light fills the circle
/// and the dove has landed in it. Static under Reduce Motion.
public struct ThresholdWindow: View {
    public enum Presence: Sendable {
        /// Waiting — the light breathes.
        case breathing
        /// Still and quiet (empty states, illustrations).
        case still
        /// The pause is complete — the light fills the circle and the dove rests in it.
        case open
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var inhale = false

    let width: CGFloat
    let light: Color
    let presence: Presence
    let showsDove: Bool

    /// `showsDove`: show the resting dove even before the pause is complete (brand moments
    /// such as the welcome screen). It always shows when `presence` is `.open`.
    public init(width: CGFloat = 200, light: Color = PLLight.current(), presence: Presence = .breathing, showsDove: Bool = false) {
        self.width = width
        self.light = light
        self.presence = presence
        self.showsDove = showsDove
    }

    public var body: some View {
        ZStack {
            Circle()
                .fill(Color.plSurface)
            // The light: a soft glow from the centre.
            RadialGradient(
                colors: [glow.opacity(glowOpacity), glow.opacity(0)],
                center: .center,
                startRadius: 0,
                endRadius: width * glowRadius
            )
            .scaleEffect(inhale ? 1.08 : 0.88)
            .clipShape(Circle())
            if presence == .open || showsDove {
                // The faith's colour, with a gilt far wing — never a dark silhouette.
                DoveMark(color: colorScheme == .dark ? Color.plInk : Color.plAccent, farWing: Color.plGilt.opacity(0.7))
                    .frame(width: width * 0.66, height: width * 0.46)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            } else {
                // A point of light at its heart.
                Circle()
                    .fill(Color.plGilt)
                    .frame(width: coreSize, height: coreSize)
                    .shadow(color: glow.opacity(0.9), radius: 10)
                    .scaleEffect(inhale ? 1.15 : 0.85)
            }
            // Double rule, traced in gold leaf.
            Circle()
                .strokeBorder(Color.plGilt.opacity(0.85), lineWidth: 1)
            Circle()
                .inset(by: width * 0.05)
                .stroke(Color.plGilt.opacity(0.35), lineWidth: 0.75)
        }
        .frame(width: width, height: width)
        .accessibilityHidden(true)
        .onAppear(perform: startBreathing)
        .onChange(of: reduceMotion) { _, _ in startBreathing() }
    }

    /// The hour's light by day; candle-gilt at night, so it never reads as a muddy wash.
    private var glow: Color { colorScheme == .dark ? Color.plGilt : light }

    private var glowOpacity: Double {
        switch presence {
        case .breathing: colorScheme == .dark ? 0.55 : 0.85
        case .still: colorScheme == .dark ? 0.4 : 0.6
        case .open: colorScheme == .dark ? 0.6 : 0.9
        }
    }

    private var glowRadius: CGFloat { presence == .open ? 0.62 : 0.48 }
    private var coreSize: CGFloat { max(6, width * 0.045) }

    private func startBreathing() {
        guard presence == .breathing, !reduceMotion else {
            inhale = true
            return
        }
        inhale = false
        withAnimation(PLMotion.breath.repeatForever(autoreverses: true)) {
            inhale = true
        }
    }
}

/// The small brand mark: the gilt dove. Used in headers and the welcome lockup.
public struct ThresholdMark: View {
    let size: CGFloat

    public init(size: CGFloat = 22) { self.size = size }

    public var body: some View {
        DoveMark(color: .plGilt)
            .frame(width: size * 1.45, height: size)
    }
}

/// Content scrolling under the status bar on screens without a navigation bar fades out
/// at the top edge instead of colliding with the clock. Backgrounds (the hour's light) are
/// untouched because only the scrolling content is masked.
public struct PLScrollEdgeFade: ViewModifier {
    public init() {}

    public func body(content: Content) -> some View {
        content.mask {
            VStack(spacing: 0) {
                LinearGradient(colors: [.black.opacity(0), .black], startPoint: .top, endPoint: .bottom)
                    .frame(height: 20)
                Color.black
            }
        }
    }
}

public extension View {
    func plScrollEdgeFade() -> some View { modifier(PLScrollEdgeFade()) }
}
