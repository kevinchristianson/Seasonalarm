import Foundation
import AVFoundation

/// Plays a silent audio loop to keep the app process alive in the background.
/// This allows AVAudioPlayer to fire alarm audio at the exact scheduled time
/// without the 30-second UNNotificationSound limit.
///
/// Usage:
///   BackgroundAudioKeepAlive.shared.start()  — call when any alarm is enabled
///   BackgroundAudioKeepAlive.shared.stop()   — call when all alarms are disabled
final class BackgroundAudioKeepAlive {

    static let shared = BackgroundAudioKeepAlive()
    private init() {}

    private var silentPlayer: AVAudioPlayer?
    private(set) var isRunning = false

    func start() {
        guard !isRunning else { return }
        guard let url = Bundle.main.url(forResource: "silent_loop", withExtension: "wav") else {
            print("⚠️ silent_loop.wav not found in bundle — background keepalive unavailable")
            return
        }
        do {
            // Must use .playback so iOS keeps the process alive when screen locks
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .default,
                options: [.duckOthers]
            )
            try AVAudioSession.sharedInstance().setActive(true)
            silentPlayer = try AVAudioPlayer(contentsOf: url)
            silentPlayer?.numberOfLoops = -1   // loop forever
            silentPlayer?.volume = 0           // truly silent
            silentPlayer?.play()
            isRunning = true
            print("🔇 Background keepalive started")
        } catch {
            print("❌ Background keepalive failed: \(error)")
        }
    }

    func stop() {
        silentPlayer?.stop()
        silentPlayer = nil
        isRunning = false
        print("🔇 Background keepalive stopped")
    }
}
