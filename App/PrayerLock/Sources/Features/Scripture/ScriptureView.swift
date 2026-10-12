import PLDesign
import PLFaith
import PLScripture
import SwiftUI

/// The faith's own scripture — "Bible", "Quran" or "Gita" in the tab bar. A contents page
/// set like the front of a well-made book: where you left off, then every book, surah or
/// chapter, then where the texts come from.
struct ScriptureView: View {
    @Environment(AppModel.self) private var model
    @State private var query = ""

    var body: some View {
        @Bindable var model = model
        NavigationStack(path: $model.scripturePath) {
            Group {
                if let readable = model.readableWork {
                    contents(readable)
                } else {
                    // The tab only exists when there is something to read; this covers the
                    // moment between a faith change and the tab bar updating.
                    Color.plCanvas
                }
            }
            .background(Color.plCanvas)
            .navigationDestination(for: ScriptureRoute.self) { route in
                switch route {
                case let .book(id):
                    BookChaptersView(bookID: id)
                case let .chapter(location, highlight):
                    ChapterReaderView(start: location, highlight: highlight)
                case .about:
                    ScriptureSourcesView()
                }
            }
        }
    }

    private func contents(_ readable: ReadableWork) -> some View {
        let work = readable.work
        let languages = model.profile.languages
        return ScrollView {
            LazyVStack(alignment: .leading, spacing: PLSpacing.xl) {
                ScreenHeader(
                    eyebrow: String(localized: "Read"),
                    title: work.title.resolved(for: languages),
                    detail: editionsLine(readable)
                )
                .padding(.top, PLSpacing.l)
                .plStaggered(0)

                continueCard(readable)
                    .plStaggered(1)

                SearchField(text: $query, label: searchPrompt(work))
                    .plStaggered(2)

                if work.isSingleBook, let book = work.books.first {
                    ChapterList(work: work, book: book, query: query)
                        .plStaggered(3)
                } else {
                    BookList(readable: readable, query: query)
                        .plStaggered(3)
                }

                NavigationLink(value: ScriptureRoute.about) {
                    HStack {
                        Text("About these texts")
                            .font(.plHeadline)
                            .foregroundStyle(Color.plInk)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color.plInkSecondary)
                            .accessibilityHidden(true)
                    }
                    .padding(PLSpacing.l)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableStyle())
                .plPaper(padding: 0)
                .accessibilityIdentifier("scripture.about")
            }
            .padding(.horizontal, PLSpacing.page)
            .padding(.bottom, PLSpacing.xxxl)
        }
        .scrollDismissesKeyboard(.interactively)
        .plScrollEdgeFade()
        .navigationTitle(work.shortTitle.resolved(for: languages))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink(value: ScriptureRoute.about) {
                    Label("About these texts", systemImage: "info.circle")
                }
                .accessibilityIdentifier("scripture.aboutToolbar")
            }
        }
    }

    /// "World English Bible · Hebrew and Greek originals"
    private func editionsLine(_ readable: ReadableWork) -> String {
        var parts: [String] = []
        if let translation = readable.translation {
            parts.append(translation.title.resolved(for: model.profile.languages))
        }
        let originals = readable.originals.map(\.languageName)
        if !originals.isEmpty {
            parts.append(String(localized: "Original \(originals.formatted(.list(type: .and)))"))
        }
        return parts.joined(separator: " · ")
    }

    private func searchPrompt(_ work: ScriptureWork) -> String {
        switch work.id {
        case "quran": String(localized: "Find a surah — name or number")
        case "bible": String(localized: "Find a book")
        default: String(localized: "Find an adhyaya — name or number")
        }
    }

    private func continueCard(_ readable: ReadableWork) -> some View {
        let saved = model.readingLocation(for: readable.work.id)
        let location = saved ?? readable.firstLocation
        return VStack(alignment: .leading, spacing: PLSpacing.m) {
            if let location {
                VStack(alignment: .leading, spacing: PLSpacing.xs) {
                    Text(saved == nil ? String(localized: "Begin reading") : String(localized: "Continue reading"))
                        .plEyebrow()
                    Text(ChapterNaming.title(location, work: readable.work, languages: model.profile.languages))
                        .font(.plTitle)
                        .foregroundStyle(Color.plInk)
                    if let subtitle = ChapterNaming.subtitle(location, work: readable.work, languages: model.profile.languages) {
                        Text(subtitle)
                            .font(.plCallout)
                            .foregroundStyle(Color.plInkSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Button(saved == nil ? String(localized: "Open") : String(localized: "Continue")) {
                    model.scripturePath.append(.chapter(location, highlight: nil))
                }
                .buttonStyle(.plPrimary)
                .accessibilityIdentifier("scripture.continue")
            }
        }
        .plPaper()
    }
}

// MARK: - Contents

/// Filters the contents. A labelled field rather than `.searchable` or a placeholder: the
/// system placeholder is light grey on grey and fails contrast, and a label stays visible
/// while typing.
private struct SearchField: View {
    @Binding var text: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: PLSpacing.xs) {
            SectionHeading(label)
            HStack(spacing: PLSpacing.s) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color.plInkSecondary)
                    .accessibilityHidden(true)
                TextField(label, text: $text, prompt: Text(verbatim: ""))
                    .font(.plBody)
                    .foregroundStyle(Color.plInk)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .accessibilityIdentifier("scripture.search")
                if !text.isEmpty {
                    Button {
                        text = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.plInkSecondary)
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel(String(localized: "Clear search"))
                }
            }
            .padding(.horizontal, PLSpacing.m)
            .frame(minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: PLRadius.control, style: .continuous)
                    .fill(Color.plSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: PLRadius.control, style: .continuous)
                    .strokeBorder(Color.plLine, lineWidth: 1)
            )
        }
    }
}

/// Bible books in two testaments.
private struct BookList: View {
    @Environment(AppModel.self) private var model
    let readable: ReadableWork
    let query: String

    var body: some View {
        let languages = model.profile.languages
        let books = readable.work.books.filter { !readable.layouts(for: $0.id).isEmpty }
            .filter { query.isEmpty || $0.title.resolved(for: languages).localizedStandardContains(query) }
        VStack(alignment: .leading, spacing: PLSpacing.xl) {
            ForEach([ScriptureBook.Group.oldTestament, .newTestament], id: \.self) { group in
                let inGroup = books.filter { $0.group == group }
                if !inGroup.isEmpty {
                    VStack(alignment: .leading, spacing: PLSpacing.s) {
                        SectionHeading(group.title)
                        VStack(spacing: 0) {
                            ForEach(Array(inGroup.enumerated()), id: \.element.id) { index, book in
                                if index > 0 { PLHairline().padding(.leading, PLSpacing.l) }
                                NavigationLink(value: ScriptureRoute.book(book.id)) {
                                    ContentsRow(
                                        title: book.title.resolved(for: languages),
                                        detail: String(localized: "\(book.chapterCount) chapters")
                                    )
                                }
                                .buttonStyle(PressableStyle())
                                .accessibilityIdentifier("scripture.book.\(book.id)")
                            }
                        }
                        .plPaper(padding: 0)
                    }
                }
            }
        }
    }
}

/// Surahs or Gita chapters, listed directly.
private struct ChapterList: View {
    @Environment(AppModel.self) private var model
    let work: ScriptureWork
    let book: ScriptureBook
    let query: String

    var body: some View {
        let languages = model.profile.languages
        let chapters = (1...max(book.chapterCount, 1)).filter { number in
            guard !query.isEmpty else { return true }
            if "\(number)" == query.trimmingCharacters(in: .whitespaces) { return true }
            let info = book.chapterInfo(number)
            return [info?.title.resolved(for: languages), info?.transliteratedTitle, info?.originalTitle]
                .compactMap { $0 }
                .contains { $0.localizedStandardContains(query) }
        }
        VStack(alignment: .leading, spacing: PLSpacing.s) {
            SectionHeading(work.id == "quran" ? String(localized: "Surahs") : String(localized: "Adhyayas"))
            LazyVStack(spacing: 0) {
                ForEach(Array(chapters.enumerated()), id: \.element) { index, number in
                    if index > 0 { PLHairline().padding(.leading, PLSpacing.xxxl) }
                    let info = book.chapterInfo(number)
                    NavigationLink(value: ScriptureRoute.chapter(ScriptureLocation(work: work.id, book: book.id, chapter: number), highlight: nil)) {
                        // Surahs are known by their transliterated names; Gita chapter names
                        // are long Sanskrit compounds, so Arnold's English title leads there.
                        let isQuran = work.id == "quran"
                        ContentsRow(
                            number: number,
                            title: (isQuran ? info?.transliteratedTitle : info?.title.resolved(for: languages))
                                ?? String(localized: "Chapter \(number)"),
                            detail: isQuran ? info?.title.resolved(for: languages) : info?.transliteratedTitle,
                            original: info?.originalTitle
                        )
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityIdentifier("scripture.chapter.\(number)")
                }
            }
            .plPaper(padding: 0)
        }
    }
}

/// One line of a contents page. At accessibility text sizes the row stacks vertically, so
/// the title keeps the full width instead of breaking mid-word beside the original name.
private struct ContentsRow: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    var number: Int?
    let title: String
    var detail: String?
    var original: String?

    var body: some View {
        Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: PLSpacing.xs) {
                    HStack {
                        numberView
                        Spacer(minLength: 0)
                        chevron
                    }
                    titles
                    if let original { originalView(original) }
                }
            } else {
                HStack(alignment: .center, spacing: PLSpacing.m) {
                    numberView
                    titles
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if let original {
                        originalView(original)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    chevron
                }
            }
        }
        .padding(.horizontal, PLSpacing.l)
        .padding(.vertical, PLSpacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    @ViewBuilder private var numberView: some View {
        if let number {
            Text("\(number)")
                .font(.plVerseNumber)
                .foregroundStyle(Color.plGilt)
                .frame(minWidth: 28, alignment: .leading)
        }
    }

    private var titles: some View {
        VStack(alignment: .leading, spacing: PLSpacing.xxs) {
            Text(title)
                .font(.plTitleSmall)
                .foregroundStyle(Color.plInk)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            if let detail {
                Text(detail)
                    .font(.plCaption)
                    .foregroundStyle(Color.plInkSecondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func originalView(_ text: String) -> some View {
        Text(text)
            .font(.plHeadline)
            .foregroundStyle(Color.plInkSecondary)
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Color.plInkSecondary)
    }
}

/// A Bible book's chapters as a grid of numbers.
struct BookChaptersView: View {
    @Environment(AppModel.self) private var model
    let bookID: String

    var body: some View {
        if let readable = model.readableWork, let book = readable.work.book(bookID) {
            let layout = readable.layout(preferred: model.preferredLayout(for: readable.work.id), for: bookID) ?? .translation
            let count = readable.chapterCount(book: bookID, layout: layout)
            ScrollView {
                VStack(alignment: .leading, spacing: PLSpacing.l) {
                    ScreenHeader(
                        eyebrow: book.group?.title ?? readable.work.title.resolved(for: model.profile.languages),
                        title: book.title.resolved(for: model.profile.languages),
                        detail: String(localized: "\(count) chapters")
                    )
                    ChapterGrid(count: count) { chapter in
                        model.scripturePath.append(.chapter(ScriptureLocation(work: readable.work.id, book: bookID, chapter: chapter), highlight: nil))
                    }
                }
                .padding(PLSpacing.page)
            }
            .background(Color.plCanvas)
            .navigationTitle(book.title.resolved(for: model.profile.languages))
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

/// Numbered tiles for jumping to a chapter.
struct ChapterGrid: View {
    let count: Int
    var current: Int?
    let onSelect: (Int) -> Void
    @ScaledMetric(relativeTo: .body) private var tile: CGFloat = 52

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: tile), spacing: PLSpacing.xs)], spacing: PLSpacing.xs) {
            ForEach(1...max(count, 1), id: \.self) { chapter in
                let isCurrent = chapter == current
                Button { onSelect(chapter) } label: {
                    Text("\(chapter)")
                        .font(.system(.body, design: .serif))
                        .monospacedDigit()
                        .foregroundStyle(isCurrent ? Color.plOnAccentFill : Color.plInk)
                        .frame(maxWidth: .infinity, minHeight: tile)
                        .background(
                            RoundedRectangle(cornerRadius: PLRadius.chip, style: .continuous)
                                .fill(isCurrent ? Color.plAccentFill : Color.plSurface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: PLRadius.chip, style: .continuous)
                                .strokeBorder(isCurrent ? Color.clear : Color.plLine, lineWidth: 1)
                        )
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel(String(localized: "Chapter \(chapter)"))
                .accessibilityAddTraits(isCurrent ? .isSelected : [])
                .accessibilityIdentifier("scripture.grid.\(chapter)")
            }
        }
    }
}

// MARK: - Sources

/// Where every bundled text comes from — attribution, licence, what was changed, and any
/// notice the licence requires (Tanzil's copyright block).
struct ScriptureSourcesView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let readable = model.readableWork
        let editions = ([readable?.translation] + (readable?.originals ?? []) + [readable?.transliteration]).compactMap { $0 }
        ScrollView {
            VStack(alignment: .leading, spacing: PLSpacing.l) {
                ScreenHeader(
                    eyebrow: String(localized: "Sources"),
                    title: String(localized: "About these texts"),
                    detail: String(localized: "Every word here comes from the editions below, unchanged except as noted. Nothing is generated.")
                )
                ForEach(editions) { edition in
                    VStack(alignment: .leading, spacing: PLSpacing.s) {
                        Text(edition.languageName).plEyebrow()
                        Text(edition.title.resolved(for: model.profile.languages))
                            .font(.plTitleSmall)
                            .foregroundStyle(Color.plInk)
                        if model.env.configuration.isDevelopment {
                            ReviewBadge(status: edition.review.status)
                        }
                        Text(edition.attribution)
                            .font(.plCallout)
                            .foregroundStyle(Color.plInk)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(edition.modifications)
                            .font(.plCaption)
                            .foregroundStyle(Color.plInkSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        if let notice = edition.notice {
                            Text(notice)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(Color.plInkSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .textSelection(.enabled)
                                .accessibilityIdentifier("scripture.notice.\(edition.id.rawValue)")
                        }
                        if let url = edition.attributionURL {
                            Link(destination: url) {
                                Label(String(localized: "Visit \(url.host() ?? url.absoluteString)"), systemImage: "arrow.up.right")
                                    .font(.plCallout)
                                    .frame(minHeight: 44, alignment: .leading)
                                    .contentShape(Rectangle())
                            }
                            .foregroundStyle(Color.plAccent)
                        }
                    }
                    .plPaper()
                }
            }
            .padding(PLSpacing.page)
        }
        .background(Color.plCanvas)
        .navigationTitle(String(localized: "Sources"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Naming

extension ScriptureBook.Group {
    var title: String {
        switch self {
        case .oldTestament: String(localized: "Old Testament")
        case .newTestament: String(localized: "New Testament")
        }
    }
}

extension ScriptureEdition {
    /// "English", "Hebrew", "Greek", "Arabic", "Sanskrit" — in the user's language.
    var languageName: String {
        let code = ["hbo": "he", "grc": "el"][language] ?? language
        if script == "Latn", language == "sa" { return String(localized: "Transliteration") }
        return Locale.current.localizedString(forLanguageCode: code)?.localizedCapitalized ?? language
    }
}

/// How chapters are named in each scripture.
enum ChapterNaming {
    /// "Psalm 23", "Al-Faatiha", "Chapter 2".
    static func title(_ location: ScriptureLocation, work: ScriptureWork, languages: [String]) -> String {
        let info = work.book(location.book)?.chapterInfo(location.chapter)
        switch work.id {
        case "quran": return info?.transliteratedTitle ?? String(localized: "Surah \(location.chapter)")
        case "bhagavad-gita": return String(localized: "Adhyaya \(location.chapter)")
        default: return ScriptureReferenceFormatter.format(chapter: location.chapter, book: location.book, in: work, languages: languages)
        }
    }

    /// "Surah 1 · The Opening", "sāṃkhyayoga · The Book of Doctrines".
    static func subtitle(_ location: ScriptureLocation, work: ScriptureWork, languages: [String]) -> String? {
        guard let info = work.book(location.book)?.chapterInfo(location.chapter) else { return nil }
        let english = info.title.resolved(for: languages)
        switch work.id {
        case "quran": return String(localized: "Surah \(location.chapter) · \(english)")
        default: return [info.transliteratedTitle, english].compactMap { $0 }.joined(separator: " · ")
        }
    }
}
