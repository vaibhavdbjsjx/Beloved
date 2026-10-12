import FamilyControls
import ManagedSettings
import PLContent
import PLDesign
import PLProtection
import SwiftUI

/// The prayer moment: Arrival → (check-in) → Reflection → Intention → Complete.
///
/// Presented full screen from a shield hand-off or from Today. It never pretends to do
/// more than iOS allows: it cannot switch the user back into the protected app, so it
/// tells them their apps are open and lets them return themselves.
struct MomentView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let request: MomentRequest

    enum Phase: Equatable {
        case arrival
        case checkIn
        case reflection
        case intention
        case complete
    }

    /// A short, gentle minimum so the moment can't be tapped through reflexively.
    static let minimumReflection: Duration = .seconds(5)

    @State private var phase: Phase = .arrival
    @State private var startedAt = Date()
    @State private var selection: ScoredContent?
    @State private var canFinish = false
    @State private var isCompleting = false
    @State private var outcome: MomentOutcome?
    @State private var chosenIntention: String?
    @State private var completions = 0

    private var light: Color { PLLight.current(calendar: model.env.calendar) }

    var body: some View {
        ZStack {
            ZStack(alignment: .top) {
                Color.plCanvas
                PLLightWash(light: light, height: 520)
            }
            .ignoresSafeArea()

            Group {
                switch phase {
                case .arrival: arrival
                case .checkIn: checkIn
                case .reflection: reflection
                case .intention: intention
                case .complete: complete
                }
            }
            .plAppearTransition()
        }
        .animation(PLMotion.animation(PLMotion.gentle, reduceMotion: reduceMotion), value: phase)
        .overlay(alignment: .topTrailing) {
            if phase != .complete {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.body.weight(.medium))
                        .foregroundStyle(Color.plInkSecondary)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Color.plSurface.opacity(0.8)))
                        .overlay(Circle().strokeBorder(Color.plLine, lineWidth: 1))
                }
                .accessibilityLabel(Text("Close"))
                .padding(.trailing, PLSpacing.m)
                .padding(.top, PLSpacing.xs)
            }
        }
        .interactiveDismissDisabled()
        .sensoryFeedback(.success, trigger: completions)
        .onAppear {
            startedAt = .now
            selection = model.selectContent()
        }
    }

    // MARK: - Arrival

    private var arrival: some View {
        VStack(spacing: PLSpacing.xl) {
            Spacer(minLength: PLSpacing.xxl)
            if let token = applicationToken {
                Label(token)
                    .font(.plHeadline)
                    .labelStyle(.titleAndIcon)
                    .padding(.horizontal, PLSpacing.m)
                    .padding(.vertical, PLSpacing.xs)
                    .background(Capsule().fill(Color.plSurface))
                    .overlay(Capsule().strokeBorder(Color.plLine, lineWidth: 1))
            }
            ThresholdWindow(width: 172, light: light, presence: .breathing)
            VStack(spacing: PLSpacing.s) {
                Text(request.trigger == .shield ? "You chose to pause here." as LocalizedStringKey : "Take a breath.")
                    .font(.plDisplay)
                    .foregroundStyle(Color.plInk)
                    .accessibilityAddTraits(.isHeader)
                Text(model.profile.faithID == nil
                    ? "Take a moment before you continue." as LocalizedStringKey
                    : "Take a moment to pray before you continue.")
                    .font(.plCallout)
                    .foregroundStyle(Color.plInkSecondary)
                Text("Breathe with the light")
                    .plEyebrow()
                    .padding(.top, PLSpacing.xs)
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: PLSpacing.l)
            Button("Begin") {
                phase = model.todayMood == nil ? .checkIn : .reflection
            }
            .buttonStyle(.plPrimary)
            .accessibilityIdentifier("moment.begin")
        }
        .padding(.horizontal, PLSpacing.page)
        .padding(.bottom, PLSpacing.l)
    }

    private var applicationToken: ApplicationToken? {
        guard let shield = request.shieldRequest, shield.subject == .application, let data = shield.tokenData else {
            return nil
        }
        return try? JSONDecoder().decode(ApplicationToken.self, from: data)
    }

    // MARK: - Optional check-in

    private var checkIn: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PLSpacing.l) {
                VStack(alignment: .leading, spacing: PLSpacing.xs) {
                    Text("How are you arriving?")
                        .font(.plDisplay)
                        .foregroundStyle(Color.plInk)
                        .accessibilityAddTraits(.isHeader)
                    Text("Optional — it helps choose words that fit today.")
                        .font(.plCallout)
                        .foregroundStyle(Color.plInkSecondary)
                }
                MoodWords(selected: model.todayMood) { mood in
                    model.checkIn(mood)
                    selection = model.selectContent()
                    phase = .reflection
                }
                Button("Skip") { phase = .reflection }
                    .buttonStyle(.plQuiet(.plInkSecondary))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, PLSpacing.page)
            .padding(.top, PLSpacing.xxxl)
            .padding(.bottom, PLSpacing.xl)
        }
        .plScrollEdgeFade()
    }

    // MARK: - Reflection (the spiritual moment)

    private var reflection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PLSpacing.xl) {
                if let item = selection?.item {
                    VStack(alignment: .leading, spacing: PLSpacing.s) {
                        Text(hourLine).plEyebrow()
                        Text(item.title.resolved(for: model.profile.languages))
                            .font(.plDisplay)
                            .foregroundStyle(Color.plInk)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                        if model.env.configuration.isDevelopment {
                            ReviewBadge(status: item.review.status)
                        }
                    }
                    PLOrnament()
                    ForEach(Array(item.segments.enumerated()), id: \.offset) { _, segment in
                        ContentSegmentView(
                            segment: segment,
                            languages: model.profile.languages,
                            showOriginal: model.profile.showOriginalScript,
                            showTransliteration: model.profile.showTransliteration,
                            editionTitle: model.editionTitle(for: segment)
                        )
                    }
                } else {
                    // No approved content for this profile yet (e.g. a release build before
                    // content review). Offer silence rather than inventing text.
                    VStack(alignment: .leading, spacing: PLSpacing.m) {
                        Text("A quiet moment").plEyebrow()
                        Text("Sit quietly for a moment.")
                            .font(.plDisplay)
                            .foregroundStyle(Color.plInk)
                            .accessibilityAddTraits(.isHeader)
                        Text("Breathe slowly. Let your shoulders fall. When you're ready, continue.")
                            .plReading()
                            .foregroundStyle(Color.plInkSecondary)
                    }
                    ThresholdWindow(width: 120, light: light, presence: .breathing)
                        .frame(maxWidth: .infinity)
                        .padding(.top, PLSpacing.l)
                }
            }
            .frame(maxWidth: 560, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, PLSpacing.page)
            .padding(.top, PLSpacing.xxxl)
            .padding(.bottom, PLSpacing.xl)
        }
        .plScrollEdgeFade()
        .safeAreaInset(edge: .bottom) {
            BreathFillButton(
                title: model.profile.faithID == nil ? "I'm ready" : "I've prayed",
                waitingTitle: "Stay a moment…",
                isReady: canFinish,
                duration: Self.minimumReflection
            ) {
                phase = .intention
            }
            .accessibilityIdentifier("moment.finish")
            .padding(.horizontal, PLSpacing.page)
            .padding(.top, PLSpacing.m)
            .padding(.bottom, PLSpacing.s)
            .background(
                LinearGradient(colors: [Color.plCanvas.opacity(0), Color.plCanvas], startPoint: .top, endPoint: .center)
                    .ignoresSafeArea()
            )
        }
        .task {
            try? await Task.sleep(for: Self.minimumReflection)
            canFinish = true
        }
    }

    /// The hour, as a quiet eyebrow ("This morning"); the passage's own provenance label
    /// says what kind of text it is, so this doesn't repeat it.
    private var hourLine: String {
        switch TimeOfDay(date: .now, calendar: model.env.calendar) {
        case .morning: String(localized: "This morning")
        case .midday: String(localized: "This afternoon")
        case .evening: String(localized: "This evening")
        case .night: String(localized: "Tonight")
        }
    }

    // MARK: - Intention

    private var intention: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PLSpacing.l) {
                VStack(alignment: .leading, spacing: PLSpacing.xs) {
                    Text("What will you do next?")
                        .font(.plDisplay)
                        .foregroundStyle(Color.plInk)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    Text("Just for you — this isn't saved.")
                        .font(.plCallout)
                        .foregroundStyle(Color.plInkSecondary)
                }
                if !model.profile.intentions.isEmpty {
                    VStack(alignment: .leading, spacing: PLSpacing.s) {
                        SectionHeading(String(localized: "Your intentions"))
                        ForEach(model.profile.intentions, id: \.self) { text in
                            IntentionOption(text: text, isPersonal: true) { finish(intention: text) }
                        }
                    }
                }
                VStack(alignment: .leading, spacing: PLSpacing.s) {
                    if !model.profile.intentions.isEmpty {
                        SectionHeading(String(localized: "Or"))
                    }
                    ForEach(Self.intentions, id: \.self) { text in
                        IntentionOption(text: text, isPersonal: false) { finish(intention: text) }
                    }
                }
                Button("Skip") { finish(intention: nil) }
                    .buttonStyle(.plQuiet(.plInkSecondary))
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("moment.intentionSkip")
            }
            .disabled(isCompleting)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, PLSpacing.page)
            .padding(.top, PLSpacing.xxxl)
            .padding(.bottom, PLSpacing.xl)
        }
        .plScrollEdgeFade()
    }

    private static let intentions = [
        String(localized: "Connect with someone"),
        String(localized: "Get something done"),
        String(localized: "Rest for a while"),
        String(localized: "Learn something"),
    ]

    private func finish(intention: String?) {
        guard !isCompleting else { return }
        isCompleting = true
        chosenIntention = intention
        Task {
            outcome = await model.completeMoment(request, item: selection?.item, startedAt: startedAt)
            phase = .complete
            completions += 1
        }
    }

    // MARK: - Complete (access)

    private var complete: some View {
        VStack(spacing: PLSpacing.l) {
            Spacer(minLength: PLSpacing.xxl)
            ThresholdWindow(width: 148, light: light, presence: .open)
            VStack(spacing: PLSpacing.s) {
                Text("Thank you for pausing.")
                    .font(.plDisplay)
                    .foregroundStyle(Color.plInk)
                    .accessibilityAddTraits(.isHeader)
                Text("Kept in your Journey, on this iPhone.")
                    .font(.plCaption)
                    .foregroundStyle(Color.plInkSecondary)
                if let chosenIntention {
                    Text("Go gently: “\(chosenIntention)”")
                        .font(.plQuote)
                        .foregroundStyle(Color.plInk)
                }
                if let outcome {
                    if let until = outcome.unlockedUntil {
                        Group {
                            if let limit = outcome.usageLimit {
                                Text("Your apps are open for \(Int(limit / 60)) minutes of use.")
                            } else {
                                Text("Your apps are open until \(until.formatted(date: .omitted, time: .shortened)).")
                            }
                        }
                        .font(.plCallout)
                        .foregroundStyle(Color.plInk)
                        Text("You can switch back to your app now.")
                            .font(.plCaption)
                            .foregroundStyle(Color.plInkSecondary)
                    } else if let error = outcome.unlockError {
                        Text(error)
                            .font(.plCallout)
                            .foregroundStyle(Color.plCaution)
                    }
                }
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: PLSpacing.l)
            Button("Done") { dismiss() }
                .buttonStyle(.plPrimary)
                .accessibilityIdentifier("moment.done")
        }
        .padding(.horizontal, PLSpacing.page)
        .padding(.bottom, PLSpacing.l)
    }
}

/// An intention to choose at the end of a moment: serif words on paper. The user's own
/// intentions carry a gilt mark.
private struct IntentionOption: View {
    let text: String
    let isPersonal: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: PLSpacing.m) {
                if isPersonal {
                    Image(systemName: "sparkle")
                        .font(.footnote)
                        .foregroundStyle(Color.plGilt)
                        .accessibilityHidden(true)
                }
                Text(text)
                    .font(isPersonal ? .plQuote : .system(.body, design: .serif))
                    .foregroundStyle(Color.plInk)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "arrow.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.plAccent)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, PLSpacing.l)
            .frame(minHeight: 56)
            .plPaper(radius: PLRadius.control, padding: 0)
            .contentShape(RoundedRectangle(cornerRadius: PLRadius.control, style: .continuous))
        }
        .buttonStyle(PressableStyle())
    }
}

/// The reflection's finish button. Instead of a greyed-out control, it fills with lapis
/// like a slow breath over the minimum reflection time, then becomes the full action.
private struct BreathFillButton: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let title: LocalizedStringKey
    let waitingTitle: LocalizedStringKey
    let isReady: Bool
    let duration: Duration
    let action: () -> Void

    @State private var progress: CGFloat = 0

    var body: some View {
        Button(action: action) {
            Text(isReady ? title : waitingTitle)
                .font(.plHeadline)
                .foregroundStyle(isReady ? Color.plOnAccentFill : Color.plInk)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background {
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: PLRadius.control, style: .continuous)
                                .fill(Color.plSurfaceRaised)
                            RoundedRectangle(cornerRadius: PLRadius.control, style: .continuous)
                                .fill(Color.plAccentFill.opacity(isReady ? 1 : 0.22))
                                .frame(width: isReady ? proxy.size.width : proxy.size.width * progress)
                        }
                    }
                }
                .contentShape(RoundedRectangle(cornerRadius: PLRadius.control, style: .continuous))
                .animation(PLMotion.animation(PLMotion.standard, reduceMotion: reduceMotion), value: isReady)
        }
        .buttonStyle(PressableStyle())
        .disabled(!isReady)
        .accessibilityHint(isReady ? Text("") : Text("Available in a few seconds"))
        .onAppear {
            let seconds = Double(duration.components.seconds)
            withAnimation(reduceMotion ? nil : .linear(duration: seconds)) {
                progress = 1
            }
        }
    }
}
