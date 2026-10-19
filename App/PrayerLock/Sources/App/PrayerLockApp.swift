import PLCore
import PLDesign
import SwiftUI
import UIKit

@main
struct PrayerLockApp: App {
    @State private var bootstrap = Bootstrap.make()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        Self.applyNavigationTypography()
    }

    /// Native navigation bars, set in Beloved's serif and ink so every screen shares one
    /// editorial voice. Scales with Dynamic Type via UIFontMetrics.
    private static func applyNavigationTypography() {
        func serif(_ style: UIFont.TextStyle, weight: UIFont.Weight) -> UIFont {
            let base = UIFont.systemFont(ofSize: UIFont.preferredFont(forTextStyle: style).pointSize, weight: weight)
            let descriptor = base.fontDescriptor.withDesign(.serif) ?? base.fontDescriptor
            return UIFontMetrics(forTextStyle: style).scaledFont(for: UIFont(descriptor: descriptor, size: 0))
        }
        let ink = UIColor(PLPalette.ink)
        let bar = UINavigationBar.appearance()
        bar.largeTitleTextAttributes = [.font: serif(.largeTitle, weight: .regular), .foregroundColor: ink]
        bar.titleTextAttributes = [.font: serif(.headline, weight: .semibold), .foregroundColor: ink]
    }

    var body: some Scene {
        WindowGroup {
            switch bootstrap {
            case let .ready(model):
                RootView()
                    .environment(model)
                    .task { await model.observeSubscription() }
                    .task { await model.observeScreenTimeAuthorization() }
                    .onChange(of: scenePhase, initial: true) { _, phase in
                        if phase == .active {
                            Task { await model.handleBecameActive() }
                        }
                    }
            case let .failed(message):
                LaunchFailureView(message: message)
            }
        }
    }
}

/// App start-up. Bundled data failing to load is a build defect, so it is shown
/// plainly rather than crashing.
enum Bootstrap {
    case ready(AppModel)
    case failed(String?)

    @MainActor
    static func make() -> Bootstrap {
        do {
            let model = AppModel(env: try AppEnvironment.live())
            model.applyPreviewProfileIfRequested()
            return .ready(model)
        } catch {
            let detail = String(describing: error)
            Log.logger(.app).fault("Launch failed: \(detail, privacy: .public)")
            // Internal error text is for developers only, never shown in release builds.
            return .failed(AppConfiguration.fromBundle().isDevelopment ? detail : nil)
        }
    }
}

private struct LaunchFailureView: View {
    let message: String?

    var body: some View {
        ContentUnavailableView {
            Label("Something went wrong", systemImage: "exclamationmark.triangle")
        } description: {
            if let message {
                Text("\(AppBrand.displayName) couldn't load its content. Please reinstall the app.\n\n\(message)")
            } else {
                Text("\(AppBrand.displayName) couldn't load its content. Please reinstall the app.")
            }
        }
        .background(Color.plCanvas)
    }
}
