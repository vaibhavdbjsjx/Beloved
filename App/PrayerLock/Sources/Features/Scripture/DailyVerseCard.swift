import PLDesign
import PLScripture
import SwiftUI

/// Today's verse from the user's own scripture: the original (where it numbers verses the
/// same way), its transliteration, and the translation — with where it comes from, a way
/// into the chapter, and sharing. Quiet buttons only: the moment stays Today's one action.
struct DailyVerseCard: View {
    @Environment(AppModel.self) private var model
    let verse: DailyVerse

    var body: some View {
        let languages = model.profile.languages
        let work = model.env.scripture.manifest.work(verse.work)
        let scheme = model.env.registry.source(verse.work)?.referenceScheme ?? .freeform
        let reference = work.map { ScriptureReferenceFormatter.format(verse.reference, in: $0, scheme: scheme, languages: languages) } ?? ""
        VStack(alignment: .leading, spacing: PLSpacing.m) {
            HStack(alignment: .firstTextBaseline) {
                Text(String(localized: "Verse for today · \(reference)"))
                    .plEyebrow()
                    .accessibilityIdentifier("today.verse.reference")
                Spacer(minLength: 0)
                if model.env.configuration.isDevelopment, let edition = verse.translationEdition ?? verse.originalEdition {
                    ReviewBadge(status: edition.review.status)
                }
            }
            if let original = verse.originalText, let edition = verse.originalEdition {
                let style = PLScriptStyle.forScript(edition.script)
                Text(original)
                    .font(style.font)
                    .lineSpacing(style.lineSpacing)
                    .foregroundStyle(Color.plInk)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, style.isRightToLeft ? PLSpacing.xxs : 0)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .environment(\.layoutDirection, style.isRightToLeft ? .rightToLeft : .leftToRight)
                if model.profile.showTransliteration, let latin = verse.transliterationText {
                    Text(latin)
                        .font(.plTransliteration)
                        .lineSpacing(4)
                        .foregroundStyle(Color.plInkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if let translation = verse.translationText {
                Text(translation)
                    .font(.plQuote)
                    .lineSpacing(6)
                    .foregroundStyle(Color.plInk)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("today.verse.text")
            }
            Text(attribution)
                .font(.plCaption)
                .foregroundStyle(Color.plInkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: PLSpacing.l) {
                Button {
                    model.openScripture(verse.location, highlight: verse.reference)
                } label: {
                    Label(String(localized: "Read \(chapterName(work))"), systemImage: "book")
                }
                .buttonStyle(.plQuiet(.plAccent))
                .accessibilityIdentifier("today.verse.read")
                ShareLink(item: shareText(reference: reference)) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.plQuiet(.plAccent))
                .accessibilityIdentifier("today.verse.share")
            }
        }
        .plPaper()
        .accessibilityElement(children: .contain)
    }

    private func chapterName(_ work: ScriptureWork?) -> String {
        guard let work else { return "" }
        return ChapterNaming.title(verse.location, work: work, languages: model.profile.languages)
    }

    /// "World English Bible" / "Tanzil Quran Text (Uthmani) · Pickthall".
    private var attribution: String {
        [verse.originalEdition, verse.translationEdition]
            .compactMap { $0?.title.resolved(for: model.profile.languages) }
            .joined(separator: " · ")
    }

    private func shareText(reference: String) -> String {
        var parts: [String] = []
        if let original = verse.originalText { parts.append(original) }
        if let translation = verse.translationText { parts.append(translation) }
        parts.append("— \(reference)")
        // Licences ask that the source travel with the text.
        for edition in [verse.originalEdition, verse.translationEdition].compactMap({ $0 }) {
            parts.append(edition.attributionURL.map { "\(edition.attribution) \($0.absoluteString)" } ?? edition.attribution)
        }
        return parts.joined(separator: "\n\n")
    }
}
