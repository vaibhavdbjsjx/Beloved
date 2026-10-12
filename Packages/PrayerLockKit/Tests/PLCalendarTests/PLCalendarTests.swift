import Foundation
@testable import PLCalendar
import PLCore
import PLFaith
import Testing

private func d(_ year: Int, _ month: Int, _ day: Int) -> CivilDate { CivilDate(year: year, month: month, day: day) }

@Suite struct ComputusTests {
    @Test(arguments: [
        (2000, d(2000, 4, 23)), (2019, d(2019, 4, 21)), (2024, d(2024, 3, 31)),
        (2025, d(2025, 4, 20)), (2026, d(2026, 4, 5)), (2027, d(2027, 3, 28)),
    ])
    func westernEaster(year: Int, expected: CivilDate) {
        #expect(EasterComputus.gregorianEaster(year: year) == expected)
    }

    @Test(arguments: [
        (2019, d(2019, 4, 28)), (2024, d(2024, 5, 5)), (2025, d(2025, 4, 20)),
        (2026, d(2026, 4, 12)), (2027, d(2027, 5, 2)),
    ])
    func orthodoxPascha(year: Int, expected: CivilDate) {
        #expect(EasterComputus.julianEasterInGregorian(year: year) == expected)
    }

    @Test func julianChristmasFallsOnJanuarySeventh() {
        #expect(DateRule.fixedJulian(month: 12, day: 25).evaluate(cycleYear: 2026) == d(2027, 1, 7))
    }

    @Test(arguments: [(2022, d(2022, 11, 27)), (2024, d(2024, 12, 1)), (2025, d(2025, 11, 30)), (2026, d(2026, 11, 29))])
    func firstSundayOfAdvent(year: Int, expected: CivilDate) {
        let rule = DateRule.weekdayBefore(month: 12, day: 25, isoWeekday: 7, occurrence: 4)
        #expect(rule.evaluate(cycleYear: year) == expected)
    }

    @Test func invalidFixedDatesDoNotOccur() {
        #expect(DateRule.fixedGregorian(month: 2, day: 29).evaluate(cycleYear: 2025) == nil)
        #expect(DateRule.fixedGregorian(month: 2, day: 29).evaluate(cycleYear: 2024) == d(2024, 2, 29))
    }
}

@Suite struct ReligiousCalendarTests {
    let calendar: ReligiousCalendar

    init() throws {
        calendar = try ReligiousCalendar.bundled()
    }

    func ids(_ date: CivilDate, _ faith: FaithID?, _ tradition: TraditionID? = nil) -> Set<OccasionID> {
        Set(calendar.observances(on: date, faith: faith, tradition: tradition).map(\.occasionID))
    }

    @Test func westernAndOrthodoxEasterAreTraditionSpecific() {
        #expect(ids(d(2026, 4, 5), "christianity", "christianity.catholic").contains("christianity.easter"))
        #expect(!ids(d(2026, 4, 5), "christianity", "christianity.orthodox").contains("christianity.easter"))
        #expect(ids(d(2026, 4, 12), "christianity", "christianity.orthodox").contains("christianity.pascha"))
        #expect(!ids(d(2026, 4, 12), "christianity", "christianity.catholic").contains("christianity.pascha"))
        // No denomination chosen: Western observances, not Julian-calendar ones.
        #expect(ids(d(2026, 4, 5), "christianity").contains("christianity.easter"))
        #expect(!ids(d(2026, 4, 12), "christianity").contains("christianity.pascha"))
    }

    @Test func lentSeason2026() throws {
        let lent = try #require(calendar.observances(on: d(2026, 3, 1), faith: "christianity", tradition: nil)
            .first { $0.occasionID == "christianity.lent" })
        #expect(lent.range == CivilDateRange(start: d(2026, 2, 18), end: d(2026, 4, 2)))
        #expect(ids(d(2026, 2, 18), "christianity").contains("christianity.ash-wednesday"))
        #expect(ids(d(2026, 4, 3), "christianity").contains("christianity.good-friday"))
    }

    @Test func observancesNeverLeakAcrossFaiths() {
        #expect(ids(d(2026, 12, 25), "islam").isDisjoint(with: ["christianity.christmas"]))
        #expect(ids(d(2026, 12, 25), nil).isEmpty)
    }

    @Test func ramadanIsAnEstimatedHijriMonth() throws {
        let year = CivilDateRange(start: d(2026, 1, 1), end: d(2026, 12, 31))
        let ramadan = try #require(calendar.observances(in: year, faith: "islam", tradition: nil)
            .first { $0.occasionID == "islam.ramadan" })
        #expect(ramadan.isEstimated)
        #expect((29...30).contains(ramadan.range.dayCount))
        // Sanity window for Ramadan 1447 AH (Umm al-Qura).
        #expect(ramadan.range.start >= d(2026, 2, 15) && ramadan.range.start <= d(2026, 2, 22))

        let start = HijriCalendar.hijriComponents(of: ramadan.range.start)
        #expect(start.month == 9 && start.day == 1)
        let dayAfter = HijriCalendar.hijriComponents(of: ramadan.range.end.adding(days: 1))
        #expect(dayAfter.month == 10 && dayAfter.day == 1)
        #expect(ids(ramadan.range.end.adding(days: 1), "islam").contains("islam.eid-al-fitr"))
    }

    @Test func hijriRejectsNonexistentDays() {
        #expect(HijriCalendar.gregorianDate(hijriYear: 1447, month: 9, day: 31) == nil)
    }

    @Test func weeklyObservances() {
        let week = CivilDateRange(start: d(2026, 9, 28), end: d(2026, 10, 4))
        let fridays = calendar.observances(in: week, faith: "islam", tradition: "islam.shia").filter { $0.occasionID == "islam.jumuah" }
        #expect(fridays.map(\.range.start) == [d(2026, 10, 2)])
        #expect(ids(d(2026, 10, 4), "christianity", "christianity.orthodox").contains("christianity.lords-day"))
    }

    @Test func hinduFestivalsWaitForSourcedTables() {
        // No panchang source has been selected yet, so nothing is invented.
        let year = CivilDateRange(start: d(2026, 1, 1), end: d(2026, 12, 31))
        let hindu = calendar.observances(in: year, faith: "hinduism", tradition: nil)
        #expect(hindu.isEmpty)
        #expect(calendar.definitions.filter { $0.faith == "hinduism" }.allSatisfy { $0.precision == .sourcedTable })
    }

    @Test func sourcedTablesRespectRegion() throws {
        let definition = ObservanceDefinition(
            id: "test.festival", faith: "hinduism", name: "Test", kind: .festival,
            schedule: .table(entries: [
                DatedEntry(range: CivilDateRange(single: d(2030, 3, 1)), region: "IN-north", source: "Test panchang"),
                DatedEntry(range: CivilDateRange(single: d(2030, 3, 2)), region: "IN-south", source: "Test panchang"),
            ]),
            precision: .sourcedTable, source: "Test"
        )
        let custom = try ReligiousCalendar(definitions: [definition])
        let march = CivilDateRange(start: d(2030, 3, 1), end: d(2030, 3, 31))
        #expect(custom.observances(in: march, faith: "hinduism", tradition: nil).count == 2)
        #expect(custom.observances(in: march, faith: "hinduism", tradition: nil, region: "IN-south").map(\.range.start) == [d(2030, 3, 2)])
    }

    @Test func rulesMustShareACalendarSystem() {
        let mixed = ObservanceDefinition(
            id: "bad", faith: "islam", name: "Bad", kind: .season,
            schedule: .rule(start: .hijri(month: 9, day: 1), end: .fixedGregorian(month: 1, day: 1)),
            precision: .estimated, source: "Test"
        )
        #expect(throws: ReligiousCalendarError.mixedCalendarSystems("bad")) { try ReligiousCalendar(definitions: [mixed]) }
    }
}

@Suite struct DevotionalAssociationTests {
    let associations = try! DevotionalAssociations.bundled()
    let monday = d(2026, 10, 5)

    @Test func offByDefault() {
        #expect(associations.associations(on: monday, profile: SpiritualProfile(faithID: "hinduism")).isEmpty)
    }

    @Test func optInSurfacesCustomWithExplanation() throws {
        let profile = SpiritualProfile(faithID: "hinduism", useDevotionalAssociations: true)
        let found = associations.associations(on: monday, profile: profile)
        let shiva = try #require(found.first)
        #expect(shiva.focus == "hinduism.shiva")
        #expect(shiva.explanation.resolved(for: ["en"]).contains("many Hindu communities"))
    }

    @Test func notAppliedToOtherFaiths() {
        let profile = SpiritualProfile(faithID: "christianity", useDevotionalAssociations: true)
        #expect(associations.associations(on: monday, profile: profile).isEmpty)
    }
}
