import Foundation
import Combine

/// Manages in-process Timer-based alarm firing.
/// Works alongside UNUserNotificationCenter — the notification still delivers
/// the banner/badge, but audio is handled here without the 30s limit.
@MainActor
final class AlarmScheduler: ObservableObject {

    static let shared = AlarmScheduler()
    private init() {}

    private var timers: [String: Timer] = [:]

    // MARK: - Public

    func rescheduleAll(_ alarms: [Alarm]) {
        cancelAll()
        let enabledAlarms = alarms.filter { $0.isEnabled }

        for alarm in enabledAlarms {
            scheduleTimer(for: alarm)
        }

        // Keep background audio alive whenever there are active alarms
        if enabledAlarms.isEmpty {
            BackgroundAudioKeepAlive.shared.stop()
        } else {
            BackgroundAudioKeepAlive.shared.start()
        }
    }

    func cancelAll() {
        timers.values.forEach { $0.invalidate() }
        timers.removeAll()
    }

    func cancel(id: String) {
        timers[id]?.invalidate()
        timers.removeValue(forKey: id)
    }

    // MARK: - Private

    private func scheduleTimer(for alarm: Alarm) {
        if alarm.repeatDays.isEmpty {
            // One-time alarm
            if let fireDate = nextFireDate(hour: alarm.hour, minute: alarm.minute, weekday: nil) {
                schedule(alarm: alarm, at: fireDate, id: alarm.id)
            }
        } else {
            // Repeating — schedule one timer per weekday
            for day in alarm.repeatDays {
                if let fireDate = nextFireDate(hour: alarm.hour, minute: alarm.minute, weekday: day.rawValue) {
                    schedule(alarm: alarm, at: fireDate, id: "\(alarm.id)_\(day.rawValue)")
                }
            }
        }
    }

    private func schedule(alarm: Alarm, at date: Date, id: String) {
        let timer = Timer(fire: date, interval: 0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.fire(alarm: alarm, timerId: id)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        timers[id] = timer

        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        print("⏰ Timer scheduled: \(alarm.label.isEmpty ? "Alarm" : alarm.label) at \(formatter.string(from: date))")
    }

    private func fire(alarm: Alarm, timerId: String) {
        print("🔔 Timer fired for alarm: \(alarm.id)")
        timers.removeValue(forKey: timerId)

        // Reschedule repeating alarms for next week
        if !alarm.repeatDays.isEmpty {
            scheduleTimer(for: alarm)
        }

        // Hand off to AlarmManager — it handles ringing state + audio
        AlarmManager.shared.startRinging(id: alarm.id)
        AudioManager.shared.playSeasonalAlarm(for: alarm)
    }

    private func nextFireDate(hour: Int, minute: Int, weekday: Int?) -> Date? {
        var comps        = DateComponents()
        comps.hour       = hour
        comps.minute     = minute
        comps.second     = 0
        comps.weekday    = weekday
        return Calendar.current.nextDate(
            after: Date(),
            matching: comps,
            matchingPolicy: .nextTime
        )
    }
}
