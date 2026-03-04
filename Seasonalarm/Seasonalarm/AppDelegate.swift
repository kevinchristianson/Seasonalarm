import UIKit
import UserNotifications
import AVFoundation

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        return url.scheme == "seasonalarm"
    }

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session setup failed: \(error)")
        }

        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { _, _ in }

        SeasonDetector.shared.requestLocation()

        let stopAction   = UNNotificationAction(identifier: NotificationAction.stop,   title: "Stop",         options: [.destructive])
        let snoozeAction = UNNotificationAction(identifier: NotificationAction.snooze, title: "Snooze 9 min", options: [])
        let alarmCategory = UNNotificationCategory(
            identifier: NotificationCategory.alarm,
            actions: [stopAction, snoozeAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        UNUserNotificationCenter.current().setNotificationCategories([alarmCategory])

        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        let alarms = AlarmManager.shared.alarms
        if alarms.contains(where: { $0.isEnabled }) {
            BackgroundAudioKeepAlive.shared.start()
            AlarmScheduler.shared.rescheduleAll(alarms)
        }
        BackgroundRefresh.scheduleNext()
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        BackgroundRefresh.scheduleNext()
    }

    // MARK: - Foreground notification delivery

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list])
    }

    // MARK: - Notification response

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        switch response.actionIdentifier {
        case NotificationAction.stop:
            Task { @MainActor in AlarmManager.shared.stopRinging() }

        case NotificationAction.snooze:
            Task { @MainActor in
                if let id = userInfo[NotificationKey.alarmId] as? String {
                    AlarmManager.shared.snoozeAlarm(id: id)
                }
            }

        case UNNotificationDismissActionIdentifier:
            Task { @MainActor in AlarmManager.shared.stopRinging() }

        default:
            Task { @MainActor in
                guard let id = userInfo[NotificationKey.alarmId] as? String,
                      let alarm = AlarmManager.shared.alarm(withId: id)
                else { return }
                if !AudioManager.shared.isPlaying {
                    AlarmManager.shared.startRinging(id: id)
                    AudioManager.shared.playSeasonalAlarm(for: alarm)
                }
            }
        }

        completionHandler()
    }
}

// MARK: - Constants

enum NotificationAction {
    static let stop   = "STOP_ALARM"
    static let snooze = "SNOOZE_ALARM"
}

enum NotificationCategory {
    static let alarm = "SEASONAL_ALARM"
}

enum NotificationKey {
    static let alarmId = "alarmId"
}
