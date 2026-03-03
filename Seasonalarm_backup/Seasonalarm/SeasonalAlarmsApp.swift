import SwiftUI
import UserNotifications

@main
struct SeasonalAlarmsApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        configureNavigationBarAppearance()
        // Register BGAppRefreshTask before the app finishes launching (required by iOS)
        BackgroundRefresh.registerTask()
        // Trim + stage all audio tracks to Library/Sounds
        AudioManager.stageAllTracks()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(AlarmManager.shared)
                .environmentObject(AudioManager.shared)
        }
    }

    private func configureNavigationBarAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        let attr: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor.white,
            .font: UIFont.monospacedSystemFont(ofSize: 15, weight: .bold)
        ]
        appearance.titleTextAttributes = attr
        appearance.largeTitleTextAttributes = attr
        UINavigationBar.appearance().standardAppearance  = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance    = appearance
        UINavigationBar.appearance().tintColor = .white
    }
}
