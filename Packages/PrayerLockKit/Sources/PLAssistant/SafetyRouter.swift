import Foundation

public enum SafetyDecision: Hashable, Sendable {
    public enum Crisis: Hashable, Sendable {
        case selfHarm
        case harmToOthers
        case abuse
    }

    case proceed
    case crisis(Crisis)
    /// Proceed with spiritual content, but state clearly that this is not medical advice.
    case proceedWithMedicalDisclaimer
    case decline
}

/// First stage of the assistant pipeline. Runs *before* anything else, on-device.
public protocol SafetyRouter: Sendable {
    func classify(_ text: String) -> SafetyDecision
}

/// Deterministic, on-device first layer of safety routing (English only in Phase 1).
///
/// This is intentionally conservative and simple: it errs toward showing support
/// resources (a false positive costs a gentle message; a false negative could cost
/// far more). It is NOT sufficient alone — a server-side classifier is planned as
/// the second layer once a generation backend exists. See docs/05-ai-architecture.md.
public struct LocalSafetyRouter: SafetyRouter {
    static let selfHarm = [
        "kill myself", "end my life", "suicide", "suicidal", "want to die", "wanna die",
        "don't want to live", "do not want to live", "hurt myself", "harm myself", "self harm",
        "self-harm", "cut myself", "no reason to live", "better off dead", "end it all",
    ]
    static let harmToOthers = [
        "kill someone", "kill him", "kill her", "kill them", "hurt someone", "want to hurt him",
        "want to hurt her", "want to hurt them",
    ]
    static let abuse = [
        "being abused", "abusing me", "he hits me", "she hits me", "they hit me", "unsafe at home",
        "afraid to go home",
    ]
    static let medicalAdvice = [
        "stop taking my", "stop my medication", "instead of medication", "instead of my medication",
        "instead of my doctor", "instead of therapy", "diagnose", "what medication", "which medication",
        "dosage", "cure my",
    ]
    /// Deliberately narrow: broad words like "mock" or "insult" also appear in sincere
    /// requests ("they mock my faith — give me strength"). Nuanced cases are left to
    /// the planned server-side classifier.
    static let disrespect = [
        "which religion is wrong", "which religion is fake", "which religion is false",
    ]

    public init() {}

    public func classify(_ text: String) -> SafetyDecision {
        let normalized = Self.normalize(text)
        if Self.selfHarm.contains(where: normalized.contains) { return .crisis(.selfHarm) }
        if Self.harmToOthers.contains(where: normalized.contains) { return .crisis(.harmToOthers) }
        if Self.abuse.contains(where: normalized.contains) { return .crisis(.abuse) }
        if Self.disrespect.contains(where: normalized.contains) { return .decline }
        if Self.medicalAdvice.contains(where: normalized.contains) { return .proceedWithMedicalDisclaimer }
        return .proceed
    }

    static func normalize(_ text: String) -> String {
        text.lowercased()
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .replacingOccurrences(of: "\u{2018}", with: "'")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            + " "
    }
}

/// Region-aware crisis resources. Every entry must be re-verified before each release
/// (numbers change); the universal fallback is always included.
public enum CrisisResources {
    public static let universal = CrisisResource(
        name: "Local emergency services",
        contact: "Call your local emergency number if you are in immediate danger.",
        region: nil
    )

    static let byRegion: [String: [CrisisResource]] = [
        "US": [CrisisResource(name: "988 Suicide & Crisis Lifeline", contact: "Call or text 988", region: "US")],
        "GB": [CrisisResource(name: "Samaritans", contact: "Call 116 123", region: "GB")],
        "IE": [CrisisResource(name: "Samaritans", contact: "Call 116 123", region: "IE")],
        "IN": [CrisisResource(name: "Tele-MANAS", contact: "Call 14416", region: "IN")],
    ]

    public static func resources(for region: String?) -> [CrisisResource] {
        (region.flatMap { byRegion[$0.uppercased()] } ?? []) + [universal]
    }
}
