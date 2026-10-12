import Foundation
@testable import PLFaith
import Testing

@Suite struct FaithRegistryTests {
    let registry: FaithRegistry

    init() throws {
        registry = try FaithRegistry.bundled()
    }

    @Test func bundledRegistrySupportsThreeFaiths() {
        #expect(Set(registry.faiths.map(\.id)) == ["christianity", "islam", "hinduism"])
    }

    @Test func faithsHaveDifferentStructures() throws {
        let islam = try #require(registry.faith("islam"))
        #expect(!islam.usesSpiritualFocus, "Islam must not offer a deity/focus choice")
        #expect(islam.practices.contains(.dua) && islam.practices.contains(.dhikr))
        #expect(!islam.practices.contains(.mantra))

        let hinduism = try #require(registry.faith("hinduism"))
        #expect(hinduism.usesSpiritualFocus)
        #expect(hinduism.focuses.contains { $0.id == "hinduism.shiva" })

        let christianity = try #require(registry.faith("christianity"))
        #expect(!christianity.usesSpiritualFocus)
        #expect(christianity.traditions.count >= 3)
    }

    @Test func lookupsResolveOwnership() {
        #expect(registry.faith(owning: TraditionID("islam.shia")) == "islam")
        #expect(registry.faith(owning: FocusID("hinduism.ganesha")) == "hinduism")
        #expect(registry.source(owning: EditionID("bible.web")) == "bible")
        #expect(registry.edition("rigveda.sa")?.license.permitsRedistribution == false)
        #expect(registry.edition("quran.ar")?.license.permitsRedistribution == true) // Tanzil CC BY 3.0
        #expect(registry.edition("bible.web")?.license.permitsRedistribution == true)
    }

    @Test func profileConsistency() {
        #expect(registry.isConsistent(SpiritualProfile()))
        #expect(registry.isConsistent(SpiritualProfile(faithID: "hinduism", traditionID: "hinduism.shaiva", focusIDs: ["hinduism.shiva"])))
        #expect(!registry.isConsistent(SpiritualProfile(faithID: "islam", traditionID: "christianity.catholic")))
        #expect(!registry.isConsistent(SpiritualProfile(faithID: "islam", focusIDs: ["hinduism.shiva"])))
        #expect(!registry.isConsistent(SpiritualProfile(faithID: nil, traditionID: "islam.sunni")))
    }

    @Test func duplicateIdentifiersAreRejected() {
        let faith = Faith(
            id: "x", name: "X", summary: "", traditionLabel: "", traditions: [],
            focusLabel: nil, focuses: [], practices: [], sources: []
        )
        #expect(throws: FaithRegistryError.duplicateIdentifier("x")) { try FaithRegistry(faiths: [faith, faith]) }
    }
}

@Suite struct LocalizedTextTests {
    @Test func resolvesPreferredThenBaseThenEnglish() {
        let text = LocalizedText(["en": "Peace", "hi": "शांति", "es": "Paz"])
        #expect(text.resolved(for: ["hi-IN"]) == "शांति")
        #expect(text.resolved(for: ["fr", "es"]) == "Paz")
        #expect(text.resolved(for: ["fr"]) == "Peace")
    }

    @Test func decodesBareStringAsEnglish() throws {
        let decoded = try JSONDecoder().decode(LocalizedText.self, from: Data(#""Grace""#.utf8))
        #expect(decoded.values == ["en": "Grace"])
    }
}

@Suite struct OnboardingFlowTests {
    let registry: FaithRegistry

    init() throws {
        registry = try FaithRegistry.bundled()
    }

    private func faith(_ id: String) throws -> Faith {
        try #require(registry.faith(FaithID(rawValue: id)))
    }

    @Test func freshInstallStartsAtWelcome() {
        #expect(OnboardingFlow(faith: nil).resumeStep(for: nil) == .welcome)
    }

    @Test func faithNeutralSkipsTraditionAndFocus() {
        let flow = OnboardingFlow(faith: nil)
        #expect(flow.step(from: .faith, offset: 1) == .personalize)
        #expect(flow.step(from: .personalize, offset: -1) == .faith)
    }

    @Test func faithWithTraditionsButNoFocusSkipsOnlyFocus() throws {
        let flow = OnboardingFlow(faith: try faith("christianity"))
        #expect(flow.step(from: .faith, offset: 1) == .tradition)
        #expect(flow.step(from: .tradition, offset: 1) == .personalize)
        #expect(flow.step(from: .personalize, offset: -1) == .tradition)
    }

    @Test func faithWithFocusesShowsEveryStep() throws {
        let flow = OnboardingFlow(faith: try faith("hinduism"))
        #expect(flow.step(from: .tradition, offset: 1) == .focus)
    }

    @Test func movingPastTheSummaryFinishesAndBackFromWelcomeGoesNowhere() {
        let flow = OnboardingFlow(faith: nil)
        #expect(flow.step(from: .notifications, offset: 1) == .summary)
        #expect(flow.step(from: .summary, offset: 1) == nil)
        #expect(flow.step(from: .welcome, offset: -1) == nil)
    }

    @Test func interruptedSetupResumesAtTheSavedStep() throws {
        let flow = OnboardingFlow(faith: try faith("islam"))
        let progress = OnboardingProgress(step: .protection, hasChosenFaith: true)
        #expect(flow.resumeStep(for: progress) == .protection)
    }

    @Test func resumingBeforeTheFaithChoiceNeedsNoChoice() {
        let progress = OnboardingProgress(step: .faith, hasChosenFaith: false)
        #expect(OnboardingFlow(faith: nil).resumeStep(for: progress) == .faith)
    }

    @Test func progressPastFaithWithoutAChoiceReturnsToTheChoice() {
        let progress = OnboardingProgress(step: .privacy, hasChosenFaith: false)
        #expect(OnboardingFlow(faith: nil).resumeStep(for: progress) == .faith)
    }

    @Test func aStepThatNoLongerAppliesReturnsToTheFaithChoice() {
        // Saved on the tradition step, but the stored profile is now faith-neutral.
        let progress = OnboardingProgress(step: .tradition, hasChosenFaith: true)
        #expect(OnboardingFlow(faith: nil).resumeStep(for: progress) == .faith)
    }

    @Test func unknownSavedStepRestartsAtWelcome() throws {
        let progress = try JSONDecoder().decode(OnboardingProgress.self, from: Data(#"{"step":99,"hasChosenFaith":true}"#.utf8))
        #expect(OnboardingFlow(faith: nil).resumeStep(for: progress) == .welcome)
    }

    @Test func corruptedProgressFailsToDecode() {
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(OnboardingProgress.self, from: Data(#"{"step":"protection"}"#.utf8))
        }
    }

    @Test func progressRoundTrips() throws {
        let progress = OnboardingProgress(step: .summary, hasChosenFaith: true)
        let data = try JSONEncoder().encode(progress)
        #expect(try JSONDecoder().decode(OnboardingProgress.self, from: data) == progress)
    }
}

@Suite struct SpiritualProfileCodingTests {
    @Test func profileSavedBeforeIntentionsStillLoads() throws {
        // Exactly the shape the previous version wrote (no `intentions` key).
        let json = #"{"faithID":"islam","traditionID":"islam.sunni","focusIDs":[],"contentLength":"standard","languages":["en"],"showOriginalScript":false,"showTransliteration":true,"useDevotionalAssociations":false,"rememberCheckIns":true,"displayName":"Amina"}"#
        let profile = try JSONDecoder().decode(SpiritualProfile.self, from: Data(json.utf8))
        #expect(profile.faithID == FaithID(rawValue: "islam"))
        #expect(profile.contentLength == .standard)
        #expect(profile.showOriginalScript == false)
        #expect(profile.displayName == "Amina")
        #expect(profile.intentions.isEmpty)
    }

    @Test func unknownOrMissingFieldsFallBackToDefaults() throws {
        let profile = try JSONDecoder().decode(SpiritualProfile.self, from: Data(#"{"contentLength":"poetic","futureField":1}"#.utf8))
        #expect(profile.contentLength == .brief)
        #expect(profile.languages == ["en"])
        #expect(profile.faithID == nil)
    }

    @Test func intentionsRoundTrip() throws {
        let profile = SpiritualProfile(intentions: ["Call my mother", "Be present at dinner"])
        let decoded = try JSONDecoder().decode(SpiritualProfile.self, from: JSONEncoder().encode(profile))
        #expect(decoded == profile)
        #expect(decoded.intentions == ["Call my mother", "Be present at dinner"])
    }

    @Test func intentionsAreTrimmedDeduplicatedAndCapped() {
        let long = String(repeating: "a", count: 200)
        let result = SpiritualProfile.normalizedIntentions(["  Rest  ", "", "rest", "Read", long, "Fifth"])
        #expect(result == ["Rest", "Read", String(repeating: "a", count: SpiritualProfile.maximumIntentionLength)])
    }
}
