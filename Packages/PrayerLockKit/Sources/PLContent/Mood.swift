import Foundation

/// The optional daily check-in answer ("How are you feeling today?").
///
/// Used only to choose fitting spiritual content. It is never interpreted as a
/// medical or psychological signal, and no screen may suggest a diagnosis.
public enum Mood: String, Codable, CaseIterable, Sendable {
    case grateful
    case anxious
    case stressed
    case sad
    case angry
    case lonely
    case hopeful
    case happy
    case seekingGuidance
    case seekingForgiveness
    case needStrength
    case needPeace
    case celebrating
    case justWantToPray
}

/// Coarse time-of-day buckets used for morning/evening content.
public enum TimeOfDay: String, Codable, CaseIterable, Sendable {
    case morning
    case midday
    case evening
    case night

    /// Morning 04:00–10:59, midday 11:00–15:59, evening 16:00–20:59, night otherwise.
    public init(date: Date, calendar: Calendar) {
        switch calendar.component(.hour, from: date) {
        case 4..<11: self = .morning
        case 11..<16: self = .midday
        case 16..<21: self = .evening
        default: self = .night
        }
    }
}
