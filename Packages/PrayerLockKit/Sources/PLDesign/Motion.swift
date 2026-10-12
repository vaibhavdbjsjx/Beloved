import SwiftUI

/// The motion language. Motion explains change (where something came from, that an action
/// landed); it never decorates or makes anyone wait. Everything honours Reduce Motion:
/// movement becomes a short cross-fade.
public enum PLMotion {
    /// Default state change: a settled spring with no bounce.
    public static let standard = Animation.spring(response: 0.42, dampingFraction: 0.92)
    /// Larger compositional changes (phase changes in a moment, screen-sized swaps).
    public static let gentle = Animation.spring(response: 0.7, dampingFraction: 0.95)
    /// Press feedback on buttons and cards.
    public static let press = Animation.spring(response: 0.25, dampingFraction: 0.8)
    /// One breath: four seconds in, the same out (paired with `repeatForever(autoreverses:)`).
    public static let breath = Animation.easeInOut(duration: 4)
    /// What Reduce Motion gets instead of any of the above.
    public static let reduced = Animation.easeInOut(duration: 0.2)

    public static func animation(_ animation: Animation, reduceMotion: Bool) -> Animation {
        reduceMotion ? reduced : animation
    }
}

public extension AnyTransition {
    /// Content arriving: fades in while rising a few points.
    static var plRise: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .offset(y: 10)),
            removal: .opacity
        )
    }
}

/// Applies `plRise`, or a plain fade when Reduce Motion is on.
public struct PLAppearTransition: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init() {}

    public func body(content: Content) -> some View {
        content.transition(reduceMotion ? .opacity : .plRise)
    }
}

/// Staggered first appearance for a screen's sections: each fades up slightly later.
public struct PLStaggeredAppear: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var visible = false
    let order: Int

    public init(order: Int) { self.order = order }

    public func body(content: Content) -> some View {
        content
            .opacity(visible ? 1 : 0)
            .offset(y: visible || reduceMotion ? 0 : 8)
            .onAppear {
                let delay = reduceMotion ? 0 : Double(order) * 0.06
                withAnimation(PLMotion.animation(PLMotion.gentle, reduceMotion: reduceMotion).delay(delay)) {
                    visible = true
                }
            }
    }
}

public extension View {
    func plAppearTransition() -> some View { modifier(PLAppearTransition()) }
    func plStaggered(_ order: Int) -> some View { modifier(PLStaggeredAppear(order: order)) }
}
