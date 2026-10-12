import Foundation

/// When Today should welcome someone back. Deliberately simple and kind: there is no
/// streak to lose, so the only question is whether it has been a while.
public enum ReturnGreeting {
    /// Strictly more than this since the last completed moment counts as "a while".
    public static let breakLength: TimeInterval = 7 * 24 * 3600

    /// `false` when there is no history (a new user isn't "returning"), and when the last
    /// moment appears to be in the future (the clock was changed) — never a misleading note.
    public static func isReturningAfterBreak(lastMoment: Date?, now: Date) -> Bool {
        guard let lastMoment else { return false }
        let elapsed = now.timeIntervalSince(lastMoment)
        return elapsed > breakLength
    }
}
