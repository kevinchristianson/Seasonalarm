import UIKit
import AVFoundation

enum SeasonalIconManager {

    /// Attempt to set the seasonal icon. Retries with backoff until success.
    /// Call this AFTER heavy launch work (staging, etc.) is complete.
    @MainActor
    static func updateIconForCurrentSeason() {
        let season = Season.current
        let target = iconName(for: season)
        let current = UIApplication.shared.alternateIconName

        print("🎨 Icon check — season: \(season.rawValue), current: '\(current ?? "primary")', target: '\(target ?? "primary")'")

        guard current != target else { print("🎨 Icon already correct"); return }
        guard UIApplication.shared.supportsAlternateIcons else {
            print("❌ supportsAlternateIcons = false — check Info.plist")
            return
        }

        // Fully reset the audio session — setAlternateIconName fails with EAGAIN
        // while the .playback category is active, even with the player stopped.
        BackgroundAudioKeepAlive.shared.stop()
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setActive(false, options: .notifyOthersOnDeactivation)
            try session.setCategory(.ambient)   // neutral category
            try session.setActive(false)
            print("🎨 Audio session reset to .ambient")
        } catch {
            print("🎨 Audio session reset warning: \(error)")
        }

        // Wait for SpringBoard to register the session change
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            attempt(target: target, retryCount: 0)
        }
    }

    @MainActor
    private static func restoreAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.duckOthers])
            try session.setActive(true)
            BackgroundAudioKeepAlive.shared.start()
            print("🎨 Audio session restored to .playback")
        } catch {
            print("🎨 Audio session restore warning: \(error)")
        }
    }

    @MainActor
    private static func attempt(target: String?, retryCount: Int) {
        let maxRetries = 5
        let delays: [Double] = [2, 3, 5, 8, 13]

        UIApplication.shared.setAlternateIconName(target) { error in
            if let error {
                let nsErr = error as NSError
                print("🎨 Attempt \(retryCount + 1) failed (domain: \(nsErr.domain) code: \(nsErr.code))")
                if retryCount < maxRetries {
                    let delay = delays[min(retryCount, delays.count - 1)]
                    print("🎨 Retrying in \(Int(delay))s...")
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        Task { @MainActor in attempt(target: target, retryCount: retryCount + 1) }
                    }
                } else {
                    print("❌ Icon switch gave up — restoring audio session")
                    restoreAudioSession()
                }
            } else {
                print("🎨 Icon successfully set to: \(target ?? "primary (Spring)")")
                restoreAudioSession()
            }
        }
    }

    static func iconName(for season: Season) -> String? {
        switch season {
        case .spring: return nil
        case .summer: return "AppIcon-Summer"
        case .fall:   return "AppIcon-Fall"
        case .winter: return "AppIcon-Winter"
        }
    }
}
