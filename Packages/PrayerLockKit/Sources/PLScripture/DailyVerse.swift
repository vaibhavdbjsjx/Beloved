import Foundation
import PLContent
import PLCore
import PLFaith

/// `daily-verses.json`: a curated list of passages per faith — references only; the text
/// always comes from the bundled editions. Gita entries also carry Arnold's lines for the
/// verse, because Arnold's poem doesn't number verses.
public struct DailyVerseCatalog: Decodable, Sendable {
    public struct Entry: Decodable, Hashable, Sendable {
        public var book: String
        public var chapter: Int
        public var firstVerse: Int
        public var lastVerse: Int
        public var translationExcerpt: String?

        public var reference: PassageReference {
            PassageReference(book: book, chapter: chapter, firstVerse: firstVerse, lastVerse: lastVerse)
        }
    }

    public struct FaithVerses: Decodable, Hashable, Sendable {
        public var work: SourceWorkID
        public var entries: [Entry]
        public var review: ReviewInfo
    }

    public var version: Int
    public var faiths: [FaithID: FaithVerses]

    /// The passage for a day. Rotates through the whole list before repeating; each faith
    /// starts at a different point. The same day always gives the same passage.
    public func entry(for faith: FaithID, on date: CivilDate) -> Entry? {
        guard let entries = faiths[faith]?.entries, !entries.isEmpty else { return nil }
        let offset = Int(StableHash.fnv1a(faith.rawValue) % UInt64(entries.count))
        let index = ((date.julianDayNumber + offset) % entries.count + entries.count) % entries.count
        return entries[index]
    }
}

/// Today's verse, resolved from the editions this build may show.
public struct DailyVerse: Hashable, Sendable {
    public var faith: FaithID
    public var work: SourceWorkID
    public var date: CivilDate
    public var reference: PassageReference
    /// The translation's own words: verses joined, or Arnold's lines for the Gita.
    public var translationText: String?
    public var translationEdition: ScriptureEdition?
    public var originalText: String?
    public var originalEdition: ScriptureEdition?
    public var transliterationText: String?

    /// Where "Read the chapter" opens.
    public var location: ScriptureLocation {
        ScriptureLocation(work: work, book: reference.book, chapter: reference.chapter)
    }
}

/// A passage resolved to the verified words of each edition this build may show. Verses are
/// attached only from editions that number them as the reference does (an English Psalm
/// reference is a different verse in the Hebrew numbering).
public struct ResolvedPassage: Hashable, Sendable {
    public var work: SourceWorkID
    public var reference: PassageReference
    public var translationText: String?
    public var translationEdition: ScriptureEdition?
    public var originalText: String?
    public var originalEdition: ScriptureEdition?
    public var transliterationText: String?

    public var location: ScriptureLocation {
        ScriptureLocation(work: work, book: reference.book, chapter: reference.chapter)
    }

    public var hasText: Bool { translationText != nil || originalText != nil }
}

extension ScriptureLibrary {
    /// Longest passage a reference may pull in (a companion answer quotes, it doesn't
    /// reproduce chapters; "Read the chapter" is one tap away).
    public static let maximumPassageVerses = 40

    /// The verified text of a passage, or `nil` when this build may show none of it or the
    /// reference doesn't exist. `translationExcerpt` substitutes for a translation that doesn't
    /// number verses (Arnold's Gita).
    public func resolve(
        _ reference: PassageReference,
        in workID: SourceWorkID,
        policy: ScripturePolicy,
        registry: FaithRegistry,
        translationExcerpt: String? = nil
    ) throws -> ResolvedPassage? {
        guard reference.verses.count <= Self.maximumPassageVerses,
              let work = manifest.work(workID),
              let readable = policy.readableWork(for: work.faith, manifest: manifest, registry: registry) else { return nil }
        let translationInfo = manifest.edition(readable.work.translation)
        let numbering = translationInfo?.unit == .verse
            ? translationInfo?.versification
            : readable.original(for: reference.book)?.versification

        func text(_ edition: ScriptureEdition?) throws -> String? {
            guard let edition, edition.unit == .verse, edition.versification == numbering else { return nil }
            do {
                return try passage(edition.id, reference).map(\.text).joined(separator: "\n")
            } catch ScriptureError.notAvailable {
                return nil
            }
        }

        var result = ResolvedPassage(work: workID, reference: reference)
        if let translation = readable.translation {
            if let excerpt = translationExcerpt {
                result.translationText = excerpt
                result.translationEdition = translation
            } else if let joined = try text(translation) {
                result.translationText = joined
                result.translationEdition = translation
            }
        }
        let original = readable.original(for: reference.book)
        if let joined = try text(original) {
            result.originalText = joined
            result.originalEdition = original
            result.transliterationText = try text(readable.transliteration)
        }
        return result.hasText ? result : nil
    }

    /// Today's verse for a faith, or `nil` when this build may show none of it.
    public func dailyVerse(
        for faith: FaithID,
        on date: CivilDate,
        policy: ScripturePolicy,
        registry: FaithRegistry
    ) throws -> DailyVerse? {
        guard let list = daily.faiths[faith], policy.permits(list),
              let entry = daily.entry(for: faith, on: date),
              let passage = try resolve(entry.reference, in: list.work, policy: policy, registry: registry,
                                        translationExcerpt: entry.translationExcerpt) else { return nil }
        var verse = DailyVerse(faith: faith, work: list.work, date: date, reference: entry.reference)
        verse.translationText = passage.translationText
        verse.translationEdition = passage.translationEdition
        verse.originalText = passage.originalText
        verse.originalEdition = passage.originalEdition
        verse.transliterationText = passage.transliterationText
        return verse
    }
}

// MARK: - References

public enum ScriptureReferenceFormatter {
    /// "Psalm 46:10", "1 Corinthians 13:4–7", "Quran 94:5–6", "Bhagavad Gita 2.47".
    public static func format(
        _ reference: PassageReference,
        in work: ScriptureWork,
        scheme: SourceWork.ReferenceScheme,
        languages: [String] = Locale.preferredLanguages
    ) -> String {
        let separator = scheme == .chapterVerse ? "." : ":"
        let verses = reference.firstVerse == reference.lastVerse
            ? "\(reference.firstVerse)"
            : "\(reference.firstVerse)–\(reference.lastVerse)"
        return "\(name(of: reference.book, in: work, languages: languages)) \(reference.chapter)\(separator)\(verses)"
    }

    /// "Psalm 23", "Quran 94", "Bhagavad Gita 2".
    public static func format(
        chapter: Int,
        book: String,
        in work: ScriptureWork,
        languages: [String] = Locale.preferredLanguages
    ) -> String {
        "\(name(of: book, in: work, languages: languages)) \(chapter)"
    }

    private static func name(of book: String, in work: ScriptureWork, languages: [String]) -> String {
        if work.isSingleBook {
            let title = work.title.resolved(for: languages)
            return title.hasPrefix("The ") ? String(title.dropFirst(4)) : title
        }
        guard let info = work.book(book) else { return book }
        return (info.referenceTitle ?? info.title).resolved(for: languages)
    }
}

extension ScriptureReferenceFormatter {
    /// Parses catalog-style references: "Psalm 46:10", "Philippians 4:6–7" (Bible),
    /// "94:5–6" (Quran), "2.47" (Gita). Returns `nil` for anything else.
    public static func parse(_ text: String, in work: ScriptureWork, languages: [String] = ["en"]) -> PassageReference? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        let bookID: String
        let numbers: Substring
        if work.isSingleBook {
            guard let only = work.books.first else { return nil }
            bookID = only.id
            numbers = Substring(trimmed)
        } else {
            guard let space = trimmed.lastIndex(of: " ") else { return nil }
            let name = String(trimmed[..<space])
            guard let book = work.books.first(where: {
                $0.id == name.uppercased()
                    || $0.title.resolved(for: languages).caseInsensitiveCompare(name) == .orderedSame
                    || $0.referenceTitle.map { $0.resolved(for: languages).caseInsensitiveCompare(name) == .orderedSame } == true
            }) else { return nil }
            bookID = book.id
            numbers = trimmed[trimmed.index(after: space)...]
        }
        let parts = numbers.split(whereSeparator: { $0 == ":" || $0 == "." })
        guard parts.count == 2, let chapter = Int(parts[0]) else { return nil }
        let range = parts[1].split(whereSeparator: { $0 == "–" || $0 == "-" })
        guard let first = range.first.flatMap({ Int($0) }) else { return nil }
        let last = range.count == 2 ? Int(range[1]) : first
        guard let last, last >= first, range.count <= 2 else { return nil }
        return PassageReference(book: bookID, chapter: chapter, firstVerse: first, lastVerse: last)
    }
}
