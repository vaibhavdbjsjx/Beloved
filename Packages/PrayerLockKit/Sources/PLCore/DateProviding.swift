import Foundation

/// Abstracts "now" so time-dependent logic (streaks, unlock windows, calendars) is testable.
public protocol DateProviding: Sendable {
    func now() -> Date
}

public struct SystemDateProvider: DateProviding {
    public init() {}
    public func now() -> Date { Date() }
}

public struct FixedDateProvider: DateProviding {
    public var date: Date
    public init(_ date: Date) { self.date = date }
    public func now() -> Date { date }
}
