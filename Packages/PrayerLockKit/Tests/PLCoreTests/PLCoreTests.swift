import Foundation
@testable import PLCore
import Testing

@Suite struct CivilDateTests {
    @Test func julianDayNumberRoundTrips() {
        for date in [CivilDate(year: 2000, month: 1, day: 1), CivilDate(year: 2024, month: 2, day: 29), CivilDate(year: 1900, month: 3, day: 1)] {
            #expect(CivilDate(julianDayNumber: date.julianDayNumber) == date)
        }
        #expect(CivilDate(year: 2000, month: 1, day: 1).julianDayNumber == 2_451_545)
    }

    @Test func weekdays() {
        let saturday = CivilDate(year: 2000, month: 1, day: 1)
        #expect(saturday.isoWeekday == 6)
        #expect(saturday.gregorianWeekday == 7)
        let sunday = CivilDate(year: 2026, month: 10, day: 4)
        #expect(sunday.isoWeekday == 7)
        #expect(sunday.gregorianWeekday == 1)
    }

    @Test func dayArithmeticAcrossBoundaries() {
        #expect(CivilDate(year: 2024, month: 2, day: 28).adding(days: 1) == CivilDate(year: 2024, month: 2, day: 29))
        #expect(CivilDate(year: 2025, month: 2, day: 28).adding(days: 1) == CivilDate(year: 2025, month: 3, day: 1))
        #expect(CivilDate(year: 2026, month: 12, day: 31).adding(days: 1) == CivilDate(year: 2027, month: 1, day: 1))
        #expect(CivilDate(year: 2026, month: 1, day: 1).days(until: CivilDate(year: 2027, month: 1, day: 1)) == 365)
        #expect(!CivilDate(year: 2025, month: 2, day: 29).isValid)
    }

    @Test func civilDateUsesCalendarTimeZone() throws {
        // 2026-03-09 06:30 UTC is still 2026-03-08 in Los Angeles.
        let instant = try #require(ISO8601DateFormatter().date(from: "2026-03-09T06:30:00Z"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/Los_Angeles"))
        #expect(CivilDate(instant, calendar: calendar) == CivilDate(year: 2026, month: 3, day: 8))
        calendar.timeZone = try #require(TimeZone(identifier: "Asia/Kolkata"))
        #expect(CivilDate(instant, calendar: calendar) == CivilDate(year: 2026, month: 3, day: 9))
    }

    @Test func rangeContainsAndOverlaps() {
        let range = CivilDateRange(start: CivilDate(year: 2026, month: 2, day: 18), end: CivilDate(year: 2026, month: 3, day: 19))
        #expect(range.contains(CivilDate(year: 2026, month: 3, day: 1)))
        #expect(!range.contains(CivilDate(year: 2026, month: 3, day: 20)))
        #expect(range.overlaps(CivilDateRange(single: CivilDate(year: 2026, month: 3, day: 19))))
        #expect(range.dayCount == 30)
    }
}

@Suite struct IdentifierTests {
    enum Tag {}
    typealias TestID = Identifier<Tag>

    @Test func encodesAsPlainString() throws {
        let data = try JSONEncoder().encode([TestID("a.b")])
        #expect(String(decoding: data, as: UTF8.self) == #"["a.b"]"#)
    }

    @Test func dictionaryKeyedByIdentifierEncodesAsObject() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode([TestID("peace"): 1])
        #expect(String(decoding: data, as: UTF8.self) == #"{"peace":1}"#)
        let decoded = try JSONDecoder().decode([TestID: Int].self, from: data)
        #expect(decoded[TestID("peace")] == 1)
    }
}

@Suite struct StorageTests {
    struct Sample: Codable, Equatable, Sendable {
        var name: String
        var count: Int
    }

    @Test func fileStoreSaveLoadUpdateDelete() throws {
        let locations = StorageLocations.temporary()
        let store = CodableFileStore<Sample>(url: locations.privateFile("sample.json"))
        #expect(try store.load() == nil)

        try store.save(Sample(name: "a", count: 1))
        #expect(try store.load() == Sample(name: "a", count: 1))

        let updated = try store.update(initial: Sample(name: "x", count: 0)) { $0.count += 1 }
        #expect(updated.count == 2)
        #expect(try store.load()?.count == 2)

        try store.delete()
        #expect(try store.load() == nil)
    }

    @Test func updateStartsFromInitialWhenEmpty() throws {
        let store = CodableFileStore<[Int]>(url: StorageLocations.temporary().privateFile("list.json"))
        try store.update(initial: []) { $0.append(7) }
        #expect(try store.load() == [7])
    }

    @Test func corruptFileSurfacesDecodingError() throws {
        let url = StorageLocations.temporary().privateFile("bad.json")
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: url)
        #expect(throws: StorageError.self) { try CodableFileStore<Sample>(url: url).load() }
    }

    @Test func keyValueStoreRoundTrip() {
        let store = InMemoryKeyValueStore()
        store.setValue(Sample(name: "b", count: 3), forKey: "k")
        #expect(store.value(Sample.self, forKey: "k") == Sample(name: "b", count: 3))
        store.removeValue(forKey: "k")
        #expect(store.value(Sample.self, forKey: "k") == nil)
    }

    @Test func sharedFileRequiresContainer() {
        let locations = StorageLocations(privateDirectory: URL(filePath: "/tmp"), sharedDirectory: nil, appGroupIdentifier: nil)
        #expect(throws: StorageError.self) { try locations.sharedFile("x.json") }
    }
}

@Suite struct ConfigurationAndHashTests {
    @Test func unresolvedBuildSettingsAreTreatedAsMissing() {
        let config = AppConfiguration.from(infoDictionary: [
            "PLEnvironment": "production",
            "PLAppGroupIdentifier": "group.example",
            "PLAssistantEndpoint": "$(PL_ASSISTANT_ENDPOINT)",
            "PLSubscriptionGroupID": "",
        ])
        #expect(config.environment == .production)
        #expect(config.appGroupIdentifier == "group.example")
        #expect(config.assistantEndpoint == nil)
        #expect(config.subscriptionGroupID == nil)
    }

    @Test func userFacingLinksMustBeHTTPS() {
        let config = AppConfiguration.from(infoDictionary: [
            "PLSupportURL": "https://example.org/support",
            "PLPrivacyPolicyURL": "http://example.org/privacy",
        ])
        #expect(config.supportURL == URL(string: "https://example.org/support"))
        #expect(config.privacyPolicyURL == nil, "Plain HTTP must never be shown as the privacy policy link")
    }

    @Test func missingOrUnresolvedLinksAreHidden() {
        let config = AppConfiguration.from(infoDictionary: [
            "PLSupportURL": "$(PL_SUPPORT_URL)",
            "PLPrivacyPolicyURL": "   ",
        ])
        #expect(config.supportURL == nil)
        #expect(config.privacyPolicyURL == nil)
        #expect(AppConfiguration.from(infoDictionary: ["PLSupportURL": "https://"]).supportURL == nil)
        #expect(AppConfiguration.from(infoDictionary: ["PLSupportURL": "support page"]).supportURL == nil)
    }

    /// A Release build with a missing, unresolved or misspelled environment must not show
    /// unreviewed content or diagnostics.
    @Test func missingOrUnknownEnvironmentFailsClosedToProduction() {
        #expect(AppConfiguration.from(infoDictionary: [:]).environment == .production)
        #expect(AppConfiguration.from(infoDictionary: ["PLEnvironment": "$(PL_ENVIRONMENT)"]).environment == .production)
        #expect(AppConfiguration.from(infoDictionary: ["PLEnvironment": "staging"]).environment == .production)
        #expect(AppConfiguration.from(infoDictionary: ["PLEnvironment": "development"]).isDevelopment)
    }

    @Test func fnv1aMatchesReferenceVectors() {
        #expect(StableHash.fnv1a("") == 0xcbf2_9ce4_8422_2325)
        #expect(StableHash.fnv1a("a") == 0xaf63_dc4c_8601_ec8c)
    }
}

@Suite struct LegalDocumentTests {
    @Test func parsesHeadingsBulletsAndParagraphs() {
        let document = LegalDocument.parse(markdown: """
        # Privacy Policy

        Last updated: today

        ## Short version

        - No account.
        * No tracking.

        First line of a paragraph
        continues here.
        ### Detail
        """)
        #expect(document.title == "Privacy Policy")
        #expect(document.blocks == [
            .title("Privacy Policy"),
            .paragraph("Last updated: today"),
            .heading("Short version"),
            .bullet("No account."),
            .bullet("No tracking."),
            .paragraph("First line of a paragraph continues here."),
            .subheading("Detail"),
        ])
    }

    @Test func emptyMarkersAreNotBlocks() {
        #expect(LegalDocument.parse(markdown: "#\n- \n\n").blocks == [.paragraph("# -")])
        #expect(LegalDocument.parse(markdown: "").blocks.isEmpty)
    }
}
