import PLDesign
import PLFaith
import PLScripture
import SwiftUI

/// One chapter, typeset for reading: verse numbers hang in the margin, original scripts get
/// room for their marks, and the reader chooses translation, original, or both (only where
/// the two number verses the same way).
struct ChapterReaderView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let start: ScriptureLocation
    let highlight: PassageReference?

    @State private var location: ScriptureLocation?
    @State private var layout: ReadingLayout?
    @State private var page: ChapterPage?
    @State private var failed = false
    @State private var showingChapters = false

    var body: some View {
        if let readable = model.readableWork, readable.work.id == start.work {
            reader(readable)
        } else {
            Color.plCanvas
        }
    }

    private var current: ScriptureLocation { location ?? start }

    private func reader(_ readable: ReadableWork) -> some View {
        // A verse opened from Today is shown where it is numbered: Arnold's Gita follows
        // chapters, so the Sanskrit is the place to find verse 2.47.
        let opening: ReadingLayout? = highlight != nil && readable.translation?.unit == .passage ? .original : nil
        let currentLayout = readable.layout(preferred: layout ?? opening ?? model.preferredLayout(for: readable.work.id), for: current.book) ?? .translation
        let key = PageKey(location: clamped(current, readable: readable, layout: currentLayout), layout: currentLayout,
                          transliteration: model.profile.showTransliteration)
        return ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: PLSpacing.l) {
                    header(readable, key: key)
                        .id("top")
                    if let page, page.key == key {
                        ForEach(page.rows) { row in
                            VerseView(row: row, page: page, isHighlighted: isHighlighted(row, key: key))
                                .id(row.id)
                        }
                        footer(readable, page: page)
                    } else if failed {
                        Text("This chapter couldn't be opened.")
                            .font(.plCallout)
                            .foregroundStyle(Color.plInkSecondary)
                    } else {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, PLSpacing.xxl)
                    }
                }
                .padding(.horizontal, PLSpacing.page)
                .padding(.bottom, PLSpacing.xxxl)
            }
            .plScrollEdgeFade()
            .background(Color.plCanvas)
            .task(id: key) {
                await load(key, readable: readable)
                if let target = highlightTarget(key) {
                    withAnimation(PLMotion.animation(PLMotion.gentle, reduceMotion: reduceMotion)) {
                        proxy.scrollTo(target, anchor: .top)
                    }
                } else {
                    proxy.scrollTo("top", anchor: .top)
                }
            }
        }
        .navigationTitle(ChapterNaming.title(key.location, work: readable.work, languages: model.profile.languages))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingChapters = true
                } label: {
                    Label("Chapters", systemImage: "square.grid.3x3")
                }
                .accessibilityIdentifier("reader.chapters")
            }
        }
        .sheet(isPresented: $showingChapters) {
            chapterSheet(readable, key: key)
        }
        .onChange(of: key.location) { _, newValue in model.saveReadingLocation(newValue) }
        .onAppear { model.saveReadingLocation(key.location) }
    }

    // MARK: - Header

    private func header(_ readable: ReadableWork, key: PageKey) -> some View {
        let work = readable.work
        let languages = model.profile.languages
        let info = work.book(key.location.book)?.chapterInfo(key.location.chapter)
        let available = readable.layouts(for: key.location.book)
        return VStack(alignment: .leading, spacing: PLSpacing.m) {
            VStack(alignment: .leading, spacing: PLSpacing.xs) {
                Text(eyebrow(work, key: key)).plEyebrow()
                Text(ChapterNaming.title(key.location, work: work, languages: languages))
                    .font(.plDisplay)
                    .foregroundStyle(Color.plInk)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("reader.title")
                if let original = info?.originalTitle {
                    Text(original)
                        .font(.plTitle)
                        .foregroundStyle(Color.plInkSecondary)
                }
                if let subtitle = ChapterNaming.subtitle(key.location, work: work, languages: languages) {
                    Text(subtitle)
                        .font(.plCallout)
                        .foregroundStyle(Color.plInkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if available.count > 1 {
                PLFlowLayout {
                    ForEach(available, id: \.self) { option in
                        PLChip(title(of: option, readable: readable, book: key.location.book), isSelected: option == key.layout) {
                            layout = option
                            model.setPreferredLayout(option, for: work.id)
                        }
                        .accessibilityIdentifier("reader.layout.\(option.rawValue)")
                    }
                }
            }
            if let note = note(readable, key: key) {
                Text(note)
                    .font(.plCaption)
                    .foregroundStyle(Color.plInkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if model.env.configuration.isDevelopment,
               let edition = readable.primaryEdition(for: key.layout, book: key.location.book) {
                ReviewBadge(status: edition.review.status)
            }
            PLOrnament()
                .frame(maxWidth: .infinity)
                .padding(.top, PLSpacing.xs)
        }
        .padding(.top, PLSpacing.l)
    }

    private func eyebrow(_ work: ScriptureWork, key: PageKey) -> String {
        if work.isSingleBook { return work.title.resolved(for: model.profile.languages) }
        return work.book(key.location.book)?.group?.title ?? work.title.resolved(for: model.profile.languages)
    }

    private func title(of layout: ReadingLayout, readable: ReadableWork, book: String) -> String {
        switch layout {
        case .translation: readable.translation?.languageName ?? String(localized: "Translation")
        case .original: readable.original(for: book)?.languageName ?? String(localized: "Original")
        case .parallel: String(localized: "Both")
        }
    }

    /// Honest notes about what the reader is looking at.
    private func note(_ readable: ReadableWork, key: PageKey) -> String? {
        let original = readable.original(for: key.location.book)
        switch key.layout {
        case .original, .parallel:
            if let original, let translation = readable.translation, original.versification != translation.versification,
               translation.unit == .verse {
                return String(localized: "Chapter and verse numbers here follow the \(original.languageName) text and sometimes differ from English Bibles.")
            }
            return nil
        case .translation:
            if readable.translation?.unit == .passage {
                return String(localized: "Arnold's translation is a poem that follows each chapter, not each verse. Choose \(original?.languageName ?? String(localized: "Original")) to read verse by verse.")
            }
            return nil
        }
    }

    // MARK: - Footer

    private func footer(_ readable: ReadableWork, page: ChapterPage) -> some View {
        VStack(alignment: .leading, spacing: PLSpacing.l) {
            PLOrnament()
                .frame(maxWidth: .infinity)
            VStack(alignment: .leading, spacing: PLSpacing.xs) {
                ForEach(page.editions) { edition in
                    Text(edition.attribution)
                        .font(.plCaption)
                        .foregroundStyle(Color.plInkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    // Tanzil asks every use to name the source and link to tanzil.net.
                    if edition.notice != nil, let url = edition.attributionURL {
                        Link(destination: url) {
                            Label(String(localized: "Source: \(url.host() ?? url.absoluteString)"), systemImage: "arrow.up.right")
                                .font(.plCaption)
                                .frame(minHeight: 44, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        .foregroundStyle(Color.plAccent)
                        .accessibilityIdentifier("reader.sourceLink")
                    }
                }
            }
            HStack(spacing: PLSpacing.s) {
                if let previous = neighbor(-1, readable: readable, key: page.key) {
                    Button {
                        location = previous
                    } label: {
                        Label(ChapterNaming.title(previous, work: readable.work, languages: model.profile.languages), systemImage: "chevron.left")
                            .lineLimit(1)
                    }
                    .buttonStyle(.plSecondary)
                    .accessibilityIdentifier("reader.previous")
                }
                if let next = neighbor(1, readable: readable, key: page.key) {
                    Button {
                        location = next
                    } label: {
                        HStack(spacing: PLSpacing.xs) {
                            Text(ChapterNaming.title(next, work: readable.work, languages: model.profile.languages))
                                .lineLimit(1)
                            Image(systemName: "chevron.right")
                                .accessibilityHidden(true)
                        }
                    }
                    .buttonStyle(.plSecondary)
                    .accessibilityIdentifier("reader.next")
                }
            }
        }
        .padding(.top, PLSpacing.l)
    }

    // MARK: - Chapters sheet

    private func chapterSheet(_ readable: ReadableWork, key: PageKey) -> some View {
        NavigationStack {
            ScrollView {
                ChapterGrid(count: readable.chapterCount(book: key.location.book, layout: key.layout), current: key.location.chapter) { chapter in
                    location = ScriptureLocation(work: readable.work.id, book: key.location.book, chapter: chapter)
                    showingChapters = false
                }
                .padding(PLSpacing.page)
            }
            .background(Color.plCanvas)
            .navigationTitle(readable.work.isSingleBook
                ? readable.work.shortTitle.resolved(for: model.profile.languages)
                : readable.work.book(key.location.book)?.title.resolved(for: model.profile.languages) ?? "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showingChapters = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(Color.plCanvas)
    }

    // MARK: - Navigation

    /// A chapter the layout really has (Malachi 4 → Malachi 3 in Hebrew).
    private func clamped(_ location: ScriptureLocation, readable: ReadableWork, layout: ReadingLayout) -> ScriptureLocation {
        let count = readable.chapterCount(book: location.book, layout: layout)
        guard count > 0 else { return location }
        var result = location
        result.chapter = min(max(location.chapter, 1), count)
        return result
    }

    /// The previous or next chapter, continuing into the neighbouring book.
    private func neighbor(_ step: Int, readable: ReadableWork, key: PageKey) -> ScriptureLocation? {
        let here = key.location
        let count = readable.chapterCount(book: here.book, layout: key.layout)
        let target = here.chapter + step
        if (1...max(count, 1)).contains(target), count > 0 {
            return ScriptureLocation(work: here.work, book: here.book, chapter: target)
        }
        let books = readable.work.books.map(\.id).filter { readable.chapterCount(book: $0, layout: key.layout) > 0 }
        guard let index = books.firstIndex(of: here.book) else { return nil }
        let otherIndex = index + step
        guard books.indices.contains(otherIndex) else { return nil }
        let other = books[otherIndex]
        let chapter = step > 0 ? 1 : readable.chapterCount(book: other, layout: key.layout)
        return ScriptureLocation(work: here.work, book: other, chapter: chapter)
    }

    private func isHighlighted(_ row: ChapterPage.Row, key: PageKey) -> Bool {
        guard let highlight, let number = row.number, key.location.book == highlight.book,
              key.location.chapter == highlight.chapter, key.layout != .original || page?.numbersMatchReference == true else { return false }
        return highlight.verses.contains(number)
    }

    private func highlightTarget(_ key: PageKey) -> Int? {
        guard highlight != nil, let page, page.key == key else { return nil }
        return page.rows.first { isHighlighted($0, key: key) }?.id
    }

    // MARK: - Loading

    private func load(_ key: PageKey, readable: ReadableWork) async {
        failed = false
        let library = model.env.scripture
        let book = key.location.book
        let chapter = key.location.chapter
        do {
            var editions: [ScriptureEdition] = []
            var rows: [ChapterPage.Row] = []
            var originalStyle: PLScriptStyle?
            switch key.layout {
            case .translation:
                guard let translation = readable.translation,
                      let text = try await library.chapter(translation.id, book: book, chapter: chapter) else { throw ReaderError.missing }
                editions = [translation]
                let numbered = translation.unit == .verse
                rows = text.units.map {
                    .init(id: $0.number, number: numbered ? $0.number : nil, speaker: $0.speaker, translation: $0.text)
                }
            case .original, .parallel:
                guard let original = readable.original(for: book),
                      let text = try await library.chapter(original.id, book: book, chapter: chapter) else { throw ReaderError.missing }
                editions = [original]
                originalStyle = .forScript(original.script)
                var latin: ScriptureChapter?
                if key.transliteration, let transliteration = readable.transliteration {
                    latin = try await library.chapter(transliteration.id, book: book, chapter: chapter)
                    editions.append(transliteration)
                }
                var english: ScriptureChapter?
                if key.layout == .parallel, let translation = readable.translation {
                    english = try await library.chapter(translation.id, book: book, chapter: chapter)
                    editions.append(translation)
                }
                rows = text.units.map { unit in
                    let latinUnit = latin?.unit(unit.number)
                    return .init(
                        id: unit.number,
                        number: unit.number,
                        speaker: latinUnit?.speaker ?? unit.speaker,
                        original: unit.text,
                        transliteration: latinUnit?.text,
                        translation: english?.unit(unit.number)?.text
                    )
                }
            }
            let numbering = readable.translation?.unit == .verse ? readable.translation?.versification : readable.original(for: book)?.versification
            page = ChapterPage(
                key: key,
                rows: rows,
                editions: editions,
                originalStyle: originalStyle,
                arabicNumerals: originalStyle?.isRightToLeft == true && readable.original(for: book)?.script == "Arab",
                numbersMatchReference: readable.original(for: book)?.versification == numbering
            )
        } catch {
            page = nil
            failed = true
        }
    }

    private enum ReaderError: Error { case missing }
}

// MARK: - Page model

struct PageKey: Hashable {
    var location: ScriptureLocation
    var layout: ReadingLayout
    var transliteration: Bool
}

struct ChapterPage: Equatable {
    struct Row: Identifiable, Equatable {
        var id: Int
        var number: Int?
        var speaker: String?
        var original: String?
        var transliteration: String?
        var translation: String?
    }

    var key: PageKey
    var rows: [Row]
    var editions: [ScriptureEdition]
    var originalStyle: PLScriptStyle?
    var arabicNumerals: Bool
    var numbersMatchReference: Bool

    static func == (lhs: ChapterPage, rhs: ChapterPage) -> Bool { lhs.key == rhs.key && lhs.rows == rhs.rows }
}

// MARK: - Verse

/// A verse (or one of Arnold's passages): number in the margin, speaker above, original,
/// transliteration and translation stacked.
private struct VerseView: View {
    let row: ChapterPage.Row
    let page: ChapterPage
    let isHighlighted: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: PLSpacing.xs) {
            if let speaker = row.speaker {
                Text(speaker)
                    .plEyebrow(.plInkSecondary)
                    .padding(.leading, row.number == nil ? 0 : marginWidth + PLSpacing.s)
            }
            HStack(alignment: .firstTextBaseline, spacing: PLSpacing.s) {
                if let number = row.number {
                    Text(numberText(number))
                        .font(.plVerseNumber)
                        .foregroundStyle(Color.plGilt)
                        .frame(minWidth: marginWidth, alignment: .trailing)
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: PLSpacing.s) {
                    if let original = row.original, let style = page.originalStyle {
                        // In a right-to-left environment "leading" is the right edge, so the
                        // line starts where Arabic and Hebrew readers expect it.
                        Text(original)
                            .font(style.font)
                            .lineSpacing(style.lineSpacing)
                            .foregroundStyle(Color.plInk)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                            // Room for marks above and below the line (harakat, niqqud).
                            .padding(.vertical, style.isRightToLeft ? PLSpacing.xxs : 0)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .environment(\.layoutDirection, style.isRightToLeft ? .rightToLeft : .leftToRight)
                    }
                    if let transliteration = row.transliteration {
                        Text(transliteration)
                            .font(.plTransliteration)
                            .lineSpacing(4)
                            .foregroundStyle(Color.plInkSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let translation = row.translation {
                        if row.original == nil {
                            Text(translation).plReading()
                        } else {
                            Text(translation)
                                .font(.plPrayer)
                                .lineSpacing(6)
                                .foregroundStyle(Color.plInk)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            // Original alone in a right-to-left script: the number sits at the right margin.
            .environment(\.layoutDirection, isRightToLeftRow ? .rightToLeft : .leftToRight)
        }
        .padding(.vertical, isHighlighted ? PLSpacing.s : 0)
        .padding(.horizontal, isHighlighted ? PLSpacing.s : 0)
        .background {
            if isHighlighted {
                RoundedRectangle(cornerRadius: PLRadius.control, style: .continuous)
                    .fill(Color.plAccentSoft)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
        .accessibilityIdentifier(row.number.map { "reader.verse.\($0)" } ?? "reader.passage.\(row.id)")
    }

    @ScaledMetric(relativeTo: .caption) private var marginWidth: CGFloat = 22

    private var isRightToLeftRow: Bool {
        page.originalStyle?.isRightToLeft == true && row.translation == nil && row.transliteration == nil
    }

    private func numberText(_ number: Int) -> String {
        page.arabicNumerals ? number.formatted(.number.locale(Locale(identifier: "ar"))) : "\(number)"
    }

    private var accessibilityText: String {
        var parts: [String] = []
        if let number = row.number { parts.append(String(localized: "Verse \(number)")) }
        if let speaker = row.speaker { parts.append(speaker) }
        if let original = row.original { parts.append(original) }
        if let transliteration = row.transliteration { parts.append(transliteration) }
        if let translation = row.translation { parts.append(translation) }
        return parts.joined(separator: ". ")
    }
}
