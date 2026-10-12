import PLAssistant
import PLCompanion
import PLContent
import PLDesign
import PLScripture
import SwiftUI

/// A quiet place to talk: about prayer, scripture, or the day. Every holy text in an answer is
/// quoted from a verified source and labelled; the companion's own words are labelled as AI.
struct CompanionView: View {
    @Environment(AppModel.self) private var model
    @State private var companion = CompanionModel()
    @State private var draft = ""
    @State private var confirmingNew = false
    @State private var showingPaywall = false
    @FocusState private var composing: Bool

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: PLSpacing.l) {
                        if companion.conversation.messages.isEmpty {
                            welcome
                        }
                        if model.env.monetization.isPaywallEnabled && model.accessLevel != .premium {
                            premiumPrompt
                        }
                        ForEach(companion.conversation.messages) { message in
                            CompanionMessageRow(message: message)
                                .id(message.id)
                        }
                        if let streaming = companion.streamingText {
                            StreamingReply(text: streaming)
                                .id("streaming")
                        } else if companion.isResponding {
                            ThinkingDots().id("streaming")
                        }
                        if let notice = companion.notice {
                            Text(notice)
                                .font(.plCaption)
                                .foregroundStyle(Color.plInkSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityIdentifier("companion.notice")
                        }
                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .padding(.horizontal, PLSpacing.page)
                    .padding(.top, PLSpacing.m)
                    .padding(.bottom, PLSpacing.l)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: companion.conversation.messages.count) { _, _ in
                    withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                }
                .onChange(of: companion.streamingText) { _, _ in
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
            .background(Color.plCanvas)
            .safeAreaInset(edge: .bottom) { composer }
            .navigationTitle("Companion")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !companion.conversation.messages.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            confirmingNew = true
                        } label: {
                            Label("New conversation", systemImage: "square.and.pencil")
                        }
                        .accessibilityIdentifier("companion.new")
                    }
                }
            }
            .confirmationDialog("Start a new conversation?", isPresented: $confirmingNew, titleVisibility: .visible) {
                Button("Start over", role: .destructive) { companion.startOver() }
            } message: {
                Text("This conversation will be deleted from this iPhone.")
            }
        }
        .onAppear { companion.attach(model) }
        .sheet(isPresented: $showingPaywall) {
            NavigationStack { PaywallView() }
                .environment(model)
        }
    }

    // MARK: - Welcome

    private var welcome: some View {
        VStack(alignment: .leading, spacing: PLSpacing.l) {
            ThresholdWindow(width: 96, light: PLLight.current(calendar: model.env.calendar), presence: .still, showsDove: true)
                .frame(maxWidth: .infinity)
                .padding(.top, PLSpacing.l)
            VStack(alignment: .leading, spacing: PLSpacing.xs) {
                Text(companion.usesCloud ? String(localized: "Companion") : String(localized: "Ask Beloved"))
                    .plEyebrow()
                Text(greeting)
                    .font(.plDisplay)
                    .foregroundStyle(Color.plInk)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text(companion.usesCloud
                     ? String(localized: "Talk about prayer, scripture, or whatever today holds. Premium messages are sent to Beloved's server and Google Gemini for the reply; every verse and prayer I share is quoted from a verified source.")
                     : String(localized: "Ask for a prayer, a verse, or words for how you feel. Answers come from Beloved's verified library on this iPhone."))
                    .font(.plCallout)
                    .foregroundStyle(Color.plInkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            PLFlowLayout(spacing: PLSpacing.xs, lineSpacing: PLSpacing.xs) {
                ForEach(suggestions, id: \.self) { suggestion in
                    Button {
                        companion.send(suggestion)
                    } label: {
                        Text(suggestion)
                            .font(.system(.callout, design: .serif))
                            .foregroundStyle(Color.plInk)
                            .multilineTextAlignment(.leading)
                            .padding(.horizontal, PLSpacing.m)
                            .padding(.vertical, PLSpacing.s)
                            .frame(minHeight: 44)
                            .background(Color.plSurface, in: RoundedRectangle(cornerRadius: PLRadius.control, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: PLRadius.control, style: .continuous).strokeBorder(Color.plLine, lineWidth: 1))
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityIdentifier("companion.suggestion")
                }
            }
        }
    }

    private var premiumPrompt: some View {
        VStack(alignment: .leading, spacing: PLSpacing.m) {
            HStack(alignment: .top, spacing: PLSpacing.m) {
                Image(systemName: "sparkles")
                    .font(.headline)
                    .foregroundStyle(Color.plGilt)
                    .frame(width: 28, height: 28)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: PLSpacing.xxs) {
                    Text("Unlock the AI Companion")
                        .font(.plHeadline)
                        .foregroundStyle(Color.plInk)
                    Text("Free answers use Beloved's verified library on this iPhone. Premium adds a cloud companion for deeper conversation.")
                        .font(.plCaption)
                        .foregroundStyle(Color.plInkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Button("See Premium") { showingPaywall = true }
                .buttonStyle(.plSecondary)
                .accessibilityIdentifier("companion.paywall")
        }
        .plPaper()
    }

    private var greeting: String {
        switch model.profile.faithID?.rawValue {
        case "islam": String(localized: "Assalamu alaikum. What's on your heart?")
        case "hinduism": String(localized: "Namaste. What's on your heart?")
        case "christianity": String(localized: "Peace be with you. What's on your heart?")
        default: String(localized: "Welcome. What's on your heart?")
        }
    }

    private var suggestions: [String] {
        switch model.profile.faithID?.rawValue {
        case "christianity": [
            String(localized: "A prayer for anxiety"),
            String(localized: "Help me forgive someone"),
            String(localized: "What does Psalm 23 mean?"),
            String(localized: "A blessing for my family"),
        ]
        case "islam": [
            String(localized: "A dua for hard times"),
            String(localized: "Help me focus in salah"),
            String(localized: "What does Surah Al-Inshirah teach?"),
            String(localized: "Dhikr for a calm heart"),
        ]
        case "hinduism": [
            String(localized: "A mantra for peace of mind"),
            String(localized: "A mantra during pregnancy"),
            String(localized: "Explain Gita 2.47"),
            String(localized: "Prayer for courage before exams"),
        ]
        default: [
            String(localized: "Help me slow down"),
            String(localized: "Words for a hard day"),
            String(localized: "A gratitude practice"),
        ]
        }
    }

    // MARK: - Composer

    private var composer: some View {
        HStack(alignment: .bottom, spacing: PLSpacing.s) {
            TextField(String(localized: "Message"), text: $draft, prompt: Text(verbatim: ""), axis: .vertical)
                .font(.plBody)
                .foregroundStyle(Color.plInk)
                .lineLimit(1...5)
                .focused($composing)
                .padding(.horizontal, PLSpacing.m)
                .padding(.vertical, PLSpacing.s)
                .frame(minHeight: 44)
                .background(Color.plSurface, in: RoundedRectangle(cornerRadius: PLRadius.control + 6, style: .continuous))
                .overlay(alignment: .leading) {
                    if draft.isEmpty {
                        Text(companion.usesCloud ? "Write to your companion" : "Ask for a prayer or a verse")
                            .font(.plBody)
                            .foregroundStyle(Color.plInkSecondary)
                            .padding(.horizontal, PLSpacing.m)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                }
                .overlay(RoundedRectangle(cornerRadius: PLRadius.control + 6, style: .continuous).strokeBorder(Color.plLine, lineWidth: 1))
                .accessibilityIdentifier("companion.input")
            Button {
                if companion.isResponding {
                    companion.stop()
                } else {
                    companion.send(draft)
                    draft = ""
                }
            } label: {
                Image(systemName: companion.isResponding ? "stop.fill" : "arrow.up")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.plOnAccentFill)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(sendEnabled ? Color.plAccentFill : Color.plSurfaceRaised))
            }
            .disabled(!sendEnabled)
            .accessibilityLabel(companion.isResponding ? String(localized: "Stop") : String(localized: "Send"))
            .accessibilityIdentifier("companion.send")
        }
        .padding(.horizontal, PLSpacing.page)
        .padding(.vertical, PLSpacing.s)
        .background(Color.plCanvas)
    }

    private var sendEnabled: Bool {
        companion.isResponding || !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

// MARK: - Messages

private struct CompanionMessageRow: View {
    @Environment(AppModel.self) private var model
    let message: CompanionMessage
    @State private var blocks: [ResolvedCompanionBlock]?

    var body: some View {
        if message.role == .user {
            HStack {
                Spacer(minLength: PLSpacing.xxl)
                Text(message.text)
                    .font(.plBody)
                    .foregroundStyle(Color.plOnAccentFill)
                    .padding(.horizontal, PLSpacing.m)
                    .padding(.vertical, PLSpacing.s)
                    .background(Color.plAccentFill, in: RoundedRectangle(cornerRadius: PLRadius.control + 4, style: .continuous))
                    .textSelection(.enabled)
            }
            .accessibilityIdentifier("companion.user")
        } else {
            VStack(alignment: .leading, spacing: PLSpacing.m) {
                Text(label).plEyebrow(message.origin == .support ? .plCaution : .plGilt)
                if let blocks {
                    ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                        ResolvedBlockView(block: block)
                    }
                }
                if message.origin == .support {
                    SupportResources()
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("companion.reply")
            .task(id: message.id) {
                blocks = await model.env.companionResolver.resolve(CompanionMarkup.blocks(from: message.text))
            }
        }
    }

    private var label: String {
        switch message.origin {
        case .companion: String(localized: "Companion · AI")
        case .library: String(localized: "From Beloved's library")
        case .support: String(localized: "You're not alone")
        }
    }
}

/// The reply as it arrives: prose as written, verified texts appear once complete.
private struct StreamingReply: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: PLSpacing.m) {
            Text("Companion · AI").plEyebrow()
            ForEach(Array(CompanionMarkup.blocks(from: text, isComplete: false).enumerated()), id: \.offset) { _, block in
                switch block {
                case let .text(prose):
                    ProseText(text: prose)
                case .marker:
                    HStack(spacing: PLSpacing.s) {
                        ProgressView()
                        Text("Finding the verified text…")
                            .font(.plCaption)
                            .foregroundStyle(Color.plInkSecondary)
                    }
                    .plPaper(padding: PLSpacing.m)
                }
            }
        }
    }
}

private struct ResolvedBlockView: View {
    let block: ResolvedCompanionBlock

    var body: some View {
        switch block {
        case let .text(text):
            ProseText(text: text)
        case let .passage(passage):
            PassageCard(passage: passage)
        case let .prayer(item):
            PrayerCard(item: item)
        case let .reference(reference):
            Text(String(localized: "\(reference) — not in Beloved's verified library"))
                .font(.plCaption)
                .foregroundStyle(Color.plInkSecondary)
        }
    }
}

/// The model's own words, in the reading voice. Light Markdown (emphasis) is honoured.
private struct ProseText: View {
    let text: String

    var body: some View {
        Text(attributed)
            .font(.system(.body, design: .serif))
            .lineSpacing(5)
            .foregroundStyle(Color.plInk)
            .fixedSize(horizontal: false, vertical: true)
            .textSelection(.enabled)
    }

    private var attributed: AttributedString {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return (try? AttributedString(markdown: trimmed, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(trimmed)
    }
}

/// A verified scripture passage inside an answer, with its source and a way into the chapter.
private struct PassageCard: View {
    @Environment(AppModel.self) private var model
    let passage: ResolvedPassage

    var body: some View {
        let work = model.env.scripture.manifest.work(passage.work)
        let scheme = model.env.registry.source(passage.work)?.referenceScheme ?? .freeform
        VStack(alignment: .leading, spacing: PLSpacing.s) {
            Text(work.map { ScriptureReferenceFormatter.format(passage.reference, in: $0, scheme: scheme, languages: model.profile.languages) } ?? "")
                .plEyebrow()
            if let original = passage.originalText, let edition = passage.originalEdition {
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
                if model.profile.showTransliteration, let latin = passage.transliterationText {
                    Text(latin)
                        .font(.plTransliteration)
                        .foregroundStyle(Color.plInkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if let translation = passage.translationText {
                Text(translation).plReading()
            }
            Text([passage.originalEdition, passage.translationEdition].compactMap { $0?.title.resolved(for: model.profile.languages) }.joined(separator: " · "))
                .font(.plCaption)
                .foregroundStyle(Color.plInkSecondary)
            if model.readableWork?.work.id == passage.work {
                Button {
                    model.openScripture(passage.location, highlight: passage.reference)
                } label: {
                    Label(String(localized: "Read the chapter"), systemImage: "book")
                }
                .buttonStyle(.plQuiet(.plAccent))
            }
        }
        .plPaper()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("companion.passage")
    }
}

/// A verified prayer, mantra or dua from the library, with its provenance.
private struct PrayerCard: View {
    @Environment(AppModel.self) private var model
    let item: ContentItem

    var body: some View {
        VStack(alignment: .leading, spacing: PLSpacing.m) {
            HStack(alignment: .firstTextBaseline) {
                Text(item.title.resolved(for: model.profile.languages))
                    .font(.plTitleSmall)
                    .foregroundStyle(Color.plInk)
                Spacer(minLength: 0)
                if model.env.configuration.isDevelopment { ReviewBadge(status: item.review.status) }
            }
            ForEach(Array(item.segments.enumerated()), id: \.offset) { _, segment in
                ContentSegmentView(
                    segment: segment,
                    languages: model.profile.languages,
                    showOriginal: model.profile.showOriginalScript,
                    showTransliteration: model.profile.showTransliteration,
                    editionTitle: model.editionTitle(for: segment)
                )
            }
        }
        .plPaper()
        .accessibilityIdentifier("companion.prayer")
    }
}

/// Crisis resources for the user's region, plus the universal fallback.
private struct SupportResources: View {
    var body: some View {
        VStack(alignment: .leading, spacing: PLSpacing.s) {
            ForEach(CrisisResources.resources(for: Locale.current.region?.identifier), id: \.name) { resource in
                VStack(alignment: .leading, spacing: PLSpacing.xxs) {
                    Text(resource.name).font(.plHeadline).foregroundStyle(Color.plInk)
                    Text(resource.contact).font(.plCallout).foregroundStyle(Color.plInkSecondary)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .plPaper()
        .accessibilityIdentifier("companion.support")
    }
}

/// Three soft dots while the reply begins; still under Reduce Motion.
private struct ThinkingDots: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase = false

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.plGilt)
                    .frame(width: 7, height: 7)
                    .opacity(reduceMotion ? 0.7 : (phase ? 1 : 0.3))
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.6).repeatForever().delay(Double(index) * 0.2), value: phase)
            }
        }
        .padding(.vertical, PLSpacing.s)
        .onAppear { phase = true }
        .accessibilityElement()
        .accessibilityLabel(String(localized: "Writing a reply"))
    }
}
