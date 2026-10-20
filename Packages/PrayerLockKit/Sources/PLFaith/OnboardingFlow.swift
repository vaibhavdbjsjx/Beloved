import Foundation

/// The first-launch steps, in order. Raw values are persisted (`OnboardingProgress`),
/// so append new steps rather than reordering.
public enum OnboardingStep: Int, CaseIterable, Sendable {
    case welcome
    case faith
    case tradition
    case focus
    case personalize
    case privacy
    case protection
    case notifications
    case summary
}

/// Where an interrupted onboarding resumes. Stored with the private profile.
public struct OnboardingProgress: Codable, Equatable, Sendable {
    /// `OnboardingStep` raw value. Unknown values restart at the beginning.
    public var step: Int
    public var hasChosenFaith: Bool

    public init(step: OnboardingStep, hasChosenFaith: Bool) {
        self.step = step.rawValue
        self.hasChosenFaith = hasChosenFaith
    }
}

/// Onboarding navigation rules, kept out of the UI so they are unit-tested.
public struct OnboardingFlow: Sendable {
    /// The faith chosen so far (`nil` = not chosen yet, or faith-neutral).
    public var faith: Faith?
    /// `false` when the build has no pause-before-apps feature: the protection step is skipped.
    public var includesProtection: Bool

    public init(faith: Faith?, includesProtection: Bool = true) {
        self.faith = faith
        self.includesProtection = includesProtection
    }

    /// Tradition and focus steps only appear when the chosen faith offers them.
    public func isApplicable(_ step: OnboardingStep) -> Bool {
        switch step {
        case .tradition: !(faith?.traditions.isEmpty ?? true)
        case .focus: faith?.usesSpiritualFocus ?? false
        case .protection: includesProtection
        default: true
        }
    }

    /// The next applicable step forward (`offset > 0`) or back (`offset < 0`).
    /// `nil` going forward means onboarding is finished; going back, there is nowhere to go.
    public func step(from step: OnboardingStep, offset: Int) -> OnboardingStep? {
        guard offset != 0 else { return step }
        var index = step.rawValue + offset
        while let candidate = OnboardingStep(rawValue: index) {
            if isApplicable(candidate) { return candidate }
            index += offset.signum()
        }
        return nil
    }

    /// Where saved progress resumes. Missing or unreadable progress starts at the
    /// welcome screen; a step that needs a faith choice that was never made, or that no
    /// longer applies, falls back to the faith choice so no answer is silently skipped.
    public func resumeStep(for progress: OnboardingProgress?) -> OnboardingStep {
        guard let progress, let saved = OnboardingStep(rawValue: progress.step) else { return .welcome }
        if saved.rawValue <= OnboardingStep.faith.rawValue { return saved }
        guard progress.hasChosenFaith, isApplicable(saved) else { return .faith }
        return saved
    }
}
