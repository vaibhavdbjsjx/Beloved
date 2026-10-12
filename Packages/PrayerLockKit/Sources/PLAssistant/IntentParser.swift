import Foundation
import PLContent
import PLFaith

/// Lightweight, deterministic understanding of a request (English, Phase 1).
///
/// Good enough to route "a Quran-based dua for patience" or "a Shiva mantra for
/// Monday" to the right faith, practice, focus, and themes for retrieval. When a
/// generation backend exists, the model refines intent — but retrieval scoping stays
/// deterministic so verified sources are always chosen by code, not by the model.
public struct IntentParser: Sendable {
    let registry: FaithRegistry
    let taxonomy: ContentTaxonomy

    public init(registry: FaithRegistry, taxonomy: ContentTaxonomy) {
        self.registry = registry
        self.taxonomy = taxonomy
    }

    static let faithKeywords: [(FaithID, [String])] = [
        ("islam", ["islam", "muslim", "quran", "qur'an", "koran", "allah", "dua", "du'a", "dhikr", "surah", "ayah"]),
        ("hinduism", ["hindu", "mantra", "stotra", "gita", "veda", "bhagavan", "puja"]),
        ("christianity", ["christian", "jesus", "christ", "bible", "psalm", "gospel", "lord's prayer"]),
    ]

    static let practiceKeywords: [(PracticeKind, [String])] = [
        (.dua, ["dua", "du'a", "supplication"]),
        (.dhikr, ["dhikr", "zikr"]),
        (.mantra, ["mantra", "chant"]),
        (.stotra, ["stotra", "stotram"]),
        (.scripture, ["verse", "scripture", "psalm", "ayah", "passage"]),
        (.gratitude, ["gratitude", "thankful", "thanks"]),
        (.prayer, ["prayer", "pray"]),
    ]

    static let moodKeywords: [(Mood, [String])] = [
        (.anxious, ["anxiety", "anxious", "worried", "worry", "nervous", "fear"]),
        (.stressed, ["stress", "stressed", "overwhelmed", "pressure"]),
        (.sad, ["sad", "grief", "grieving", "heartbroken"]),
        (.angry, ["angry", "anger", "frustrated", "resentment"]),
        (.lonely, ["lonely", "alone", "isolated"]),
        (.grateful, ["grateful", "gratitude", "thankful"]),
        (.hopeful, ["hope", "hopeful"]),
        (.seekingGuidance, ["guidance", "decision", "direction", "confused"]),
        (.seekingForgiveness, ["forgive", "forgiveness", "repent", "repentance"]),
        (.needStrength, ["strength", "courage", "strong"]),
        (.needPeace, ["peace", "calm"]),
        (.celebrating, ["celebrate", "celebrating", "festival"]),
    ]

    static let weekdays = ["monday": 1, "tuesday": 2, "wednesday": 3, "thursday": 4, "friday": 5, "saturday": 6, "sunday": 7]

    public func parse(_ text: String) -> AssistantIntent {
        let normalized = LocalSafetyRouter.normalize(text)
        let words = Set(normalized.split { !$0.isLetter && $0 != "'" }.map(String.init))
        func mentions(_ keyword: String) -> Bool {
            keyword.contains(" ") ? normalized.contains(keyword) : words.contains(keyword)
        }

        var intent = AssistantIntent()

        // Focus (deity) first: it implies the faith ("a Shiva mantra").
        for faith in registry.faiths {
            for focus in faith.focuses {
                let names = [focus.name.resolved(for: ["en"])] + focus.alsoKnownAs
                if names.contains(where: { mentions($0.lowercased()) }) {
                    intent.focus = focus.id
                    intent.faith = faith.id
                    break
                }
            }
            if intent.focus != nil { break }
        }
        if intent.faith == nil {
            intent.faith = Self.faithKeywords.first { $0.1.contains(where: mentions) }?.0
        }

        intent.wantsExplanation = mentions("explain") || mentions("meaning") || normalized.contains("what does")
        intent.practice = Self.practiceKeywords.first { $0.1.contains(where: mentions) }?.0
        intent.mood = Self.moodKeywords.first { $0.1.contains(where: mentions) }?.0

        var themes = taxonomy.themes
            .filter { mentions($0.name.resolved(for: ["en"]).lowercased()) || mentions($0.id.rawValue) }
            .map(\.id)
        if let mood = intent.mood {
            themes += taxonomy.themes(for: mood).filter { !themes.contains($0) }
        }
        intent.themes = themes
        intent.isoWeekday = Self.weekdays.first { mentions($0.key) }?.value
        intent.reference = Self.reference(in: text)
        return intent
    }

    /// Finds "Book 3:16", "2:255", or "2.47"-style references.
    static func reference(in text: String) -> String? {
        let pattern = /(?:[1-3]\s?)?(?:[A-Z][a-z]+\s)?\d{1,3}[:.]\d{1,3}(?:[–-]\d{1,3})?/
        return text.firstMatch(of: pattern).map { String($0.output).trimmingCharacters(in: .whitespaces) }
    }
}
