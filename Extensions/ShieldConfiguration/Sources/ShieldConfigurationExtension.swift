import ManagedSettings
import ManagedSettingsUI
import PLBrand
import PLCore
import PLProtection
import UIKit

/// Configures the system shield shown over protected apps and websites.
///
/// iOS limits the shield to an icon, title, subtitle, colors, and two buttons (verified
/// in the iOS 27 SDK) — no custom views. So the shield is a calm *invitation*; the
/// prayer itself happens in the app.
///
/// Apple runs this extension in a sandbox that prevents moving sensitive content (it
/// receives app names) out of the extension, so it is strictly **read-only**: it never
/// writes to the App Group or the network, and never logs app names.
final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    private let state = ProtectionStateStore.shared(appGroupIdentifier: AppConfiguration.fromBundle().appGroupIdentifier)

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        makeConfiguration(appName: application.localizedDisplayName)
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        makeConfiguration(appName: application.localizedDisplayName)
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        makeConfiguration(appName: webDomain.domain)
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        makeConfiguration(appName: webDomain.domain)
    }

    private func makeConfiguration(appName: String?) -> ShieldConfiguration {
        let copy = state.shieldCopy() ?? .englishFallback
        let awaiting = state.hasPendingRequest(at: Date())
        return ShieldConfiguration(
            backgroundBlurStyle: .systemThickMaterial,
            backgroundColor: UIColor(PLPalette.canvas).withAlphaComponent(0.92),
            icon: ShieldArt.doveIcon(),
            title: .init(text: copy.title(forApp: appName), color: UIColor(PLPalette.ink)),
            subtitle: .init(text: awaiting ? copy.awaitingSubtitle : copy.subtitle, color: UIColor(PLPalette.inkSecondary)),
            primaryButtonLabel: .init(text: copy.primaryButton, color: UIColor(PLPalette.onAccent)),
            primaryButtonBackgroundColor: UIColor(PLPalette.accent),
            secondaryButtonLabel: .init(text: copy.secondaryButton, color: UIColor(PLPalette.accent))
        )
    }
}
