import Foundation
import PLContent
import PLCore
import PLFaith
import PLScripture
import os

/// Today's optional check-in answer.
struct CheckIn: Codable, Equatable {
    var date: CivilDate
    var mood: Mood
}

/// Everything about the user that the app keeps — on this device only.
struct StoredProfile: Codable, Equatable {
    var profile = SpiritualProfile()
    var onboardingCompleted = false
    /// Persisted only when `profile.rememberCheckIns` is on.
    var checkIn: CheckIn?
    /// Recently shown content (avoids repeats). Most recent first.
    var recentlyShown: [ContentItemID] = []
    /// Unfinished onboarding, so closing the app mid-setup doesn't lose answers.
    /// `nil` once onboarding is complete.
    var onboardingProgress: OnboardingProgress?
    /// Where the reader left off in each scripture, and how they like to read it.
    var reading = ReadingState()
    var dailyVerseReminder = DailyVerseReminder()

    init() {}

    // Tolerant decoding so adding fields never wipes a user's profile.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        profile = try container.decodeIfPresent(SpiritualProfile.self, forKey: .profile) ?? SpiritualProfile()
        onboardingCompleted = try container.decodeIfPresent(Bool.self, forKey: .onboardingCompleted) ?? false
        checkIn = try container.decodeIfPresent(CheckIn.self, forKey: .checkIn)
        recentlyShown = try container.decodeIfPresent([ContentItemID].self, forKey: .recentlyShown) ?? []
        // Unreadable progress only restarts onboarding; it never discards the profile.
        onboardingProgress = (try? container.decodeIfPresent(OnboardingProgress.self, forKey: .onboardingProgress)) ?? nil
        reading = (try? container.decodeIfPresent(ReadingState.self, forKey: .reading)) ?? ReadingState()
        dailyVerseReminder = (try? container.decodeIfPresent(DailyVerseReminder.self, forKey: .dailyVerseReminder)) ?? DailyVerseReminder()
    }
}


/// Private, `.complete`-protected storage for the profile (never in the App Group).
struct ProfileStore: Sendable {
    private let store: CodableFileStore<StoredProfile>
    private let log = Log.logger(.storage)

    init(fileURL: URL) {
        store = CodableFileStore(url: fileURL, protection: .complete)
    }

    func load() -> StoredProfile {
        do {
            return try store.load() ?? StoredProfile()
        } catch {
            log.error("Profile could not be read: \(String(describing: error), privacy: .public)")
            return StoredProfile()
        }
    }

    func save(_ value: StoredProfile) {
        do {
            try store.save(value)
        } catch {
            log.error("Profile could not be saved: \(String(describing: error), privacy: .public)")
        }
    }

    func delete() throws {
        try store.delete()
    }
}
