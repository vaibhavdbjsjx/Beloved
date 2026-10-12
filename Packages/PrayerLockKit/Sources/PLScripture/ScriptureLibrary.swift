import Foundation
import PLContent
import PLCore
import PLFaith

public enum ScriptureError: Error, Equatable, Sendable {
    case missingResource(String)
    case unknownEdition(EditionID)
    case notAvailable(EditionID)
}

/// Loads bundled editions on demand and keeps them in memory.
///
/// The manifest is small and read synchronously; edition texts (up to ~5 MB each) are
/// decoded off the main actor the first time a chapter of them is opened.
public actor ScriptureLibrary {
    public nonisolated let manifest: ScriptureManifest
    public nonisolated let daily: DailyVerseCatalog
    private let bundle: Bundle
    private var texts: [EditionID: EditionText] = [:]

    public init(bundle: Bundle? = nil) throws {
        let bundle = bundle ?? .module
        self.bundle = bundle
        manifest = try Self.decode(ScriptureManifest.self, named: "scripture-library", in: bundle)
        daily = try Self.decode(DailyVerseCatalog.self, named: "daily-verses", in: bundle)
    }

    /// The chapter as this edition numbers it, or `nil` when the edition doesn't have it
    /// (e.g. Malachi 4 exists in English Bibles but not in the Hebrew text).
    public func chapter(_ edition: EditionID, book: String, chapter: Int) throws -> ScriptureChapter? {
        let text = try load(edition)
        guard let bookText = text.books.first(where: { $0.id == book }),
              bookText.chapters.indices.contains(chapter - 1) else { return nil }
        let units = bookText.chapters[chapter - 1].enumerated().compactMap { index, body -> ScriptureUnit? in
            guard !body.isEmpty else { return nil }
            return ScriptureUnit(number: index + 1, text: body, speaker: bookText.speakers?["\(chapter):\(index + 1)"])
        }
        return ScriptureChapter(edition: edition, book: book, chapter: chapter, units: units)
    }

    /// The verses of a reference, in order. Throws if any verse is missing — a reference
    /// that doesn't resolve is a data error, never something to paper over.
    public func passage(_ edition: EditionID, _ reference: PassageReference) throws -> [ScriptureUnit] {
        guard let chapter = try chapter(edition, book: reference.book, chapter: reference.chapter) else {
            throw ScriptureError.notAvailable(edition)
        }
        let units = reference.verses.compactMap { chapter.unit($0) }
        guard units.count == reference.verses.count else { throw ScriptureError.notAvailable(edition) }
        return units
    }

    /// Releases decoded texts (e.g. on a memory warning); they reload on demand.
    public func purge() { texts.removeAll() }

    private func load(_ id: EditionID) throws -> EditionText {
        if let cached = texts[id] { return cached }
        guard manifest.edition(id) != nil else { throw ScriptureError.unknownEdition(id) }
        let text = try Self.decode(EditionText.self, named: id.rawValue, in: bundle)
        texts[id] = text
        return text
    }

    private static func decode<T: Decodable>(_ type: T.Type, named name: String, in bundle: Bundle) throws -> T {
        guard let url = bundle.url(forResource: name, withExtension: "json") else {
            throw ScriptureError.missingResource(name)
        }
        return try JSONDecoder().decode(T.self, from: Data(contentsOf: url))
    }
}

// MARK: - What a build may show

/// Which scripture editions reach users in a given build — the reader's counterpart of
/// `ContentPolicy`. Release shows an edition only when its rights are cleared in
/// `faiths.json` AND a reviewer has approved the bundled text.
public struct ScripturePolicy: Hashable, Sendable {
    public var requiresApproval: Bool

    public init(requiresApproval: Bool) { self.requiresApproval = requiresApproval }

    public static let release = ScripturePolicy(requiresApproval: true)
    public static let development = ScripturePolicy(requiresApproval: false)

    public func permits(_ edition: ScriptureEdition, registry: FaithRegistry) -> Bool {
        guard registry.edition(edition.id)?.license.permitsRedistribution == true else { return false }
        if requiresApproval { return edition.review.status == .approved }
        return edition.review.status != .rejected
    }

    public func permits(_ daily: DailyVerseCatalog.FaithVerses) -> Bool {
        requiresApproval ? daily.review.status == .approved : daily.review.status != .rejected
    }

    /// The parts of a work this build may show, or `nil` when none of it may be shown.
    public func readableWork(for faith: FaithID, manifest: ScriptureManifest, registry: FaithRegistry) -> ReadableWork? {
        guard let work = manifest.work(for: faith) else { return nil }
        func allowed(_ id: EditionID?) -> ScriptureEdition? {
            guard let id, let edition = manifest.edition(id), permits(edition, registry: registry) else { return nil }
            return edition
        }
        let translation = allowed(work.translation)
        let originals = work.originals.compactMap(allowed)
        guard translation != nil || !originals.isEmpty else { return nil }
        return ReadableWork(
            work: work,
            translation: translation,
            originals: originals,
            transliteration: originals.isEmpty ? nil : allowed(work.transliteration)
        )
    }
}

/// How a chapter is laid out.
public enum ReadingLayout: String, Codable, CaseIterable, Sendable {
    /// The translation alone.
    case translation
    /// The original language alone (with transliteration, where there is one and it's on).
    case original
    /// Original and translation verse by verse — only when they share numbering.
    case parallel
}

/// A work as this build may show it.
public struct ReadableWork: Hashable, Sendable {
    public var work: ScriptureWork
    public var translation: ScriptureEdition?
    public var originals: [ScriptureEdition]
    public var transliteration: ScriptureEdition?

    public func original(for book: String) -> ScriptureEdition? {
        originals.first { $0.covers(book: book) }
    }

    /// Layouts available for a book, translation first.
    public func layouts(for book: String) -> [ReadingLayout] {
        var layouts: [ReadingLayout] = []
        if translation != nil { layouts.append(.translation) }
        if let original = original(for: book) {
            layouts.append(.original)
            if let translation, work.parallel, translation.unit == .verse,
               translation.versification == original.versification {
                layouts.append(.parallel)
            }
        }
        return layouts
    }

    /// The layout to use: the reader's choice when available here, otherwise the first.
    public func layout(preferred: ReadingLayout?, for book: String) -> ReadingLayout? {
        let available = layouts(for: book)
        if let preferred, available.contains(preferred) { return preferred }
        return available.first
    }

    /// The edition whose numbering a layout navigates by.
    public func primaryEdition(for layout: ReadingLayout, book: String) -> ScriptureEdition? {
        switch layout {
        case .translation: translation
        case .original, .parallel: original(for: book)
        }
    }

    /// Chapters in a book for a layout (the Hebrew Bible has 3 chapters of Malachi, English 4).
    public func chapterCount(book: String, layout: ReadingLayout) -> Int {
        primaryEdition(for: layout, book: book)?.chapterCount(book: book) ?? 0
    }

    /// Books available for a layout, in canonical order.
    public func books(for layout: ReadingLayout) -> [ScriptureBook] {
        work.books.filter { !layouts(for: $0.id).isEmpty && (layout == .translation ? translation?.covers(book: $0.id) == true : original(for: $0.id) != nil) }
    }

    /// Where to open by default: Genesis 1, Al-Fatiha, Gita chapter 1.
    public var firstLocation: ScriptureLocation? {
        guard let book = work.books.first(where: { !layouts(for: $0.id).isEmpty }) else { return nil }
        return ScriptureLocation(work: work.id, book: book.id, chapter: 1)
    }
}
