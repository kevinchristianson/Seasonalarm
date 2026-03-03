import Foundation
import BackgroundTasks
import UIKit

/// Registers a BGAppRefreshTask that wakes the app periodically.
/// On wake, we restart the silent audio keepalive and reschedule timers
/// so alarms survive overnight reboots (e.g. iOS updates).
enum BackgroundRefresh {

    static let taskIdentifier = "com.seasonalarm.refresh"

    // MARK: - Registration (call once at launch before app finishes launching)

    static func registerTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: taskIdentifier,
            using: nil
        ) { task in
            handle(task: task as! BGAppRefreshTask)
        }
    }

    // MARK: - Schedule next refresh

    /// Ask iOS to wake us within the next 2 hours.
    /// iOS decides the exact time — we just set a minimum interval.
    static func scheduleNext() {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60 * 2)  // 2 hours minimum
        do {
            try BGTaskScheduler.shared.submit(request)
            print("📅 BGAppRefresh scheduled (earliest: 2h from now)")
        } catch {
            // BGTaskScheduler.Error.unavailable fires on simulator — ignore it
            print("📅 BGAppRefresh schedule skipped: \(error.localizedDescription)")
        }
    }

    // MARK: - Handle wake

    private static func handle(task: BGAppRefreshTask) {
        // Immediately schedule the next refresh before doing any work
        scheduleNext()

        task.expirationHandler = {
            // iOS is taking the wake back — stop cleanly
            print("📅 BGAppRefresh expiring")
            task.setTaskCompleted(success: false)
        }

        Task { @MainActor in
            print("📅 BGAppRefresh fired — restarting keepalive and timers")

            // Restart silent audio if any alarms are enabled
            let hasActive = AlarmManager.shared.alarms.contains { $0.isEnabled }
            if hasActive {
                BackgroundAudioKeepAlive.shared.start()
                AlarmScheduler.shared.rescheduleAll(AlarmManager.shared.alarms)
            }

            task.setTaskCompleted(success: true)
        }
    }
}
