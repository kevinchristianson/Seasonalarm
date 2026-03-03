import Foundation
import UserNotifications
import Combine

@MainActor
final class AlarmManager: ObservableObject {

    static let shared = AlarmManager()
    private init() {
        load()
        // Rebuild in-process timers from saved alarms on every launch
        AlarmScheduler.shared.rescheduleAll(alarms)
        rescheduleAlarmsWithMissingTracks()
    }

    @Published private(set) var alarms: [Alarm] = []
    @Published private(set) var ringingAlarmId: String? = nil

    private let storageKey = "saved_alarms_v2"

    // MARK: - CRUD

    func addAlarm(_ alarm: Alarm) {
        var a = alarm
        scheduleNotifications(for: &a)
        alarms.append(a)
        save()
        AlarmScheduler.shared.rescheduleAll(alarms)
    }

    func updateAlarm(_ alarm: Alarm) {
        guard let idx = alarms.firstIndex(where: { $0.id == alarm.id }) else { return }
        cancelNotifications(for: alarms[idx])
        var a = alarm
        if a.isEnabled { scheduleNotifications(for: &a) }
        alarms[idx] = a
        save()
        AlarmScheduler.shared.rescheduleAll(alarms)
    }

    func deleteAlarm(id: String) {
        guard let alarm = alarms.first(where: { $0.id == id }) else { return }
        cancelNotifications(for: alarm)
        if ringingAlarmId == id { stopRinging() }
        alarms.removeAll { $0.id == id }
        save()
        AlarmScheduler.shared.rescheduleAll(alarms)
    }

    func setAlarmEnabled(id: String, enabled: Bool) {
        guard let idx = alarms.firstIndex(where: { $0.id == id }) else { return }
        cancelNotifications(for: alarms[idx])
        alarms[idx].isEnabled = enabled
        if enabled {
            scheduleNotifications(for: &alarms[idx])
        } else if ringingAlarmId == id {
            stopRinging()
        }
        save()
        AlarmScheduler.shared.rescheduleAll(alarms)
    }

    func snoozeAlarm(id: String) {
        guard let alarm = alarms.first(where: { $0.id == id }) else { return }
        stopRinging()

        // Schedule both a notification (banner) and a timer (audio) for snooze
        let content = makeNotificationContent(for: alarm)
        let snoozeInterval: TimeInterval = 9 * 60
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(
                identifier: "\(alarm.id)_snooze",
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: snoozeInterval, repeats: false)
            )
        )

        // In-process snooze timer
        let snoozeDate = Date().addingTimeInterval(snoozeInterval)
        let timer = Timer(fire: snoozeDate, interval: 0, repeats: false) { _ in
            Task { @MainActor in
                AlarmManager.shared.startRinging(id: alarm.id)
                AudioManager.shared.playSeasonalAlarm(for: alarm)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
    }

    func alarm(withId id: String) -> Alarm? {
        alarms.first { $0.id == id }
    }

    // MARK: - Ringing state

    func startRinging(id: String) {
        ringingAlarmId = id
    }

    func stopRinging() {
        if let id = ringingAlarmId {
            if let alarm = alarms.first(where: { $0.id == id }), alarm.repeatDays.isEmpty {
                if let idx = alarms.firstIndex(where: { $0.id == id }) {
                    alarms[idx].isEnabled = false
                }
                save()
                AlarmScheduler.shared.rescheduleAll(alarms)
            }
        }
        ringingAlarmId = nil
        AudioManager.shared.stopAlarm()
    }

    // MARK: - Notification scheduling
    // Notifications handle the lock screen banner and actions.
    // Audio is handled by AlarmScheduler timers — not UNNotificationSound —
    // so there is no 30-second limit.

    private func scheduleNotifications(for alarm: inout Alarm) {
        guard let sourceURL = AudioManager.randomTrackURL(for: Season.current) else {
            alarm.scheduledTrackName = nil
            scheduleNotificationRequests(for: alarm)
            return
        }
        let stagedName = AudioManager.stagedFilename(for: sourceURL)
        alarm.scheduledTrackName = stagedName
        AudioManager.stageTrackForNotification(sourceURL) { result in
            if result == nil { print("⚠️ Staging failed for \(sourceURL.lastPathComponent)") }
        }
        scheduleNotificationRequests(for: alarm)
    }

    private func scheduleNotificationRequests(for alarm: Alarm) {
        let center  = UNUserNotificationCenter.current()
        let content = makeNotificationContent(for: alarm)

        if alarm.repeatDays.isEmpty {
            var comps    = DateComponents()
            comps.hour   = alarm.hour
            comps.minute = alarm.minute
            center.add(UNNotificationRequest(
                identifier: alarm.id,
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            ))
        } else {
            for day in alarm.repeatDays {
                var comps        = DateComponents()
                comps.weekday    = day.rawValue
                comps.hour       = alarm.hour
                comps.minute     = alarm.minute
                center.add(UNNotificationRequest(
                    identifier: "\(alarm.id)_\(day.rawValue)",
                    content: content,
                    trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            ))
            }
        }
    }

    private func cancelNotifications(for alarm: Alarm) {
        var ids = [alarm.id, "\(alarm.id)_snooze"]
        for day in Weekday.allCases { ids.append("\(alarm.id)_\(day.rawValue)") }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ids)
    }

    func makeNotificationContent(for alarm: Alarm) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = alarm.label.isEmpty ? "Alarm" : alarm.label
        content.body  = "Swipe left for Stop or Snooze"
        content.categoryIdentifier = NotificationCategory.alarm
        content.userInfo = [NotificationKey.alarmId: alarm.id]
        content.interruptionLevel = .timeSensitive
        // Sound is still set for the notification banner — gives immediate audio
        // feedback even if the in-process timer hasn't fired yet
        if let trackName = alarm.scheduledTrackName {
            content.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: trackName))
        } else {
            content.sound = .default
        }
        return content
    }

    private func rescheduleAlarmsWithMissingTracks() {
        var didChange = false
        for idx in alarms.indices {
            guard alarms[idx].isEnabled, alarms[idx].scheduledTrackName == nil else { continue }
            cancelNotifications(for: alarms[idx])
            scheduleNotifications(for: &alarms[idx])
            didChange = true
        }
        if didChange { save() }
    }

    // MARK: - Persistence

    private func save() {
        if let data = try? JSONEncoder().encode(alarms) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([Alarm].self, from: data)
        else { return }
        alarms = decoded
    }
}
