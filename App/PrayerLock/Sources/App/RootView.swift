import PLDesign
import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(AppearancePreference.storageKey) private var appearance: AppearancePreference = .system

    var body: some View {
        @Bindable var model = model
        ZStack {
            if model.isOnboarded {
                // Theme colours are read when drawn, so a new theme rebuilds the hierarchy.
                MainTabView()
                    .id(model.theme)
                    .transition(.opacity)
            } else {
                OnboardingView()
                    .transition(.opacity)
            }
        }
        .animation(PLMotion.animation(PLMotion.gentle, reduceMotion: reduceMotion), value: model.isOnboarded)
        .tint(.plAccent)
        .preferredColorScheme(appearance.colorScheme)
        .fullScreenCover(item: $model.activeMoment) { request in
            MomentView(request: request)
                .environment(model)
        }
        .alert(item: $model.alert) { alert in
            Alert(title: Text(alert.title), message: Text(alert.message))
        }
    }
}

/// Today, the faith's scripture, the companion, protection and settings. Journey lives on
/// Today, so the bar never grows past five. The prayer moment itself is not a tab: it is
/// presented full screen from a shield hand-off or from Today.
struct MainTabView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        TabView(selection: $model.selectedTab) {
            Tab("Today", systemImage: "sun.horizon", value: AppTab.today) {
                TodayView()
            }
            // The faith's own scripture, by its own name. Present only when this build
            // may show some of it (release builds: reviewed, rights-cleared editions).
            if let readable = model.readableWork {
                Tab(readable.work.shortTitle.resolved(for: model.profile.languages), systemImage: "book", value: AppTab.scripture) {
                    ScriptureView()
                }
                .accessibilityIdentifier("tab.scripture")
            }
            Tab("Protection", systemImage: "shield.lefthalf.filled", value: AppTab.protection) {
                ProtectionView()
            }
            Tab("Companion", systemImage: "bubble.left.and.text.bubble.right", value: AppTab.companion) {
                CompanionView()
            }
            Tab("Settings", systemImage: "gearshape", value: AppTab.settings) {
                SettingsView()
            }
        }
    }
}
