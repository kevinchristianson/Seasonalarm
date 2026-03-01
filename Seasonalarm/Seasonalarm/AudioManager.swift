import Foundation
import AVFoundation
import Combine

final class AudioManager: NSObject, ObservableObject, AVAudioPlayerDelegate {

    static let shared = AudioManager()
    private override init() { super.init() }

    @Published private(set) var isPlaying: Bool = false
    @Published private(set) var nowPlayingFile: String? = nil

    private var player: AVAudioPlayer?

    // MARK: - Public

    func playSeasonalAlarm(for alarm: Alarm) {
        let season = Season.current
        // Always use the ORIGINAL full-length bundle file for playback.
        // The staged trimmed copy is only for UNNotificationSound (lock screen).
        let url: URL?
        if let name = alarm.scheduledTrackName {
            // Match the bundle track whose sanitized name equals the stored name
            url = AudioManager.allTrackURLs(for: season).first {
                AudioManager.sanitizeFilename($0.deletingPathExtension().lastPathComponent) + ".m4a" == name
            } ?? AudioManager.randomTrackURL(for: season)
        } else {
            url = AudioManager.randomTrackURL(for: season)
        }
        guard let url else {
            print("❌ No track to play for \(season.rawValue)")
            return
        }
        print("▶️ Playing full track: \(url.lastPathComponent)")
        play(url: url)
    }

    func stopAlarm() {
        player?.stop()
        player = nil
        isPlaying = false
        nowPlayingFile = nil
    }

    // MARK: - Track discovery

    static func randomTrackName(for season: Season) -> String? {
        allTrackURLs(for: season).randomElement()?.lastPathComponent
    }

    static func randomTrackURL(for season: Season) -> URL? {
        allTrackURLs(for: season).randomElement()
    }

    static func findBundleURL(named filename: String, season: Season) -> URL? {
        for s in Season.allCases {
            if let url = allTrackURLs(for: s).first(where: { $0.lastPathComponent == filename }) {
                return url
            }
        }
        return nil
    }

    static func allTrackURLs(for season: Season) -> [URL] {
        let supported: Set<String> = ["mp3", "m4a", "aac", "wav", "aiff", "caf"]

        for root in [Bundle.main.bundleURL, Bundle.main.resourceURL].compactMap({ $0 }) {
            let folder = root.appendingPathComponent(season.folderName)
            if FileManager.default.fileExists(atPath: folder.path) {
                let found = (try? FileManager.default.contentsOfDirectory(
                    at: folder, includingPropertiesForKeys: nil
                ))?.filter { supported.contains($0.pathExtension.lowercased()) } ?? []
                if !found.isEmpty { return found }
            }
        }

        let flat = supported.flatMap { ext in
            Bundle.main.urls(forResourcesWithExtension: ext, subdirectory: nil) ?? []
        }.filter {
            $0.lastPathComponent.localizedCaseInsensitiveContains(season.folderName)
        }
        if !flat.isEmpty { return flat }

        print("❌ No tracks found for \(season.rawValue)")
        return []
    }

    // MARK: - Sound staging
    //
    // UNNotificationSound requirements:
    //   1. File must be in Library/Sounds or the app bundle
    //   2. Duration must be ≤ 30 seconds (iOS silently uses default otherwise)
    //   3. Filename must contain only safe characters (no parens, spaces, etc.)
    //
    // We trim every track to 28s and write a clean .caf to Library/Sounds.
    // CAF is Apple's preferred container — no re-encoding latency issues.

    static var soundsDirectory: URL {
        let lib = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        let dir = lib.appendingPathComponent("Sounds")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static let maxNotificationDuration: Double = 28.0

    /// Stage all tracks for all seasons. Called once at app launch.
    static func stageAllTracks(completion: (() -> Void)? = nil) {
        let group = DispatchGroup()
        for season in Season.allCases {
            let urls = allTrackURLs(for: season)
            if urls.isEmpty {
                print("⚠️ No tracks found for \(season.rawValue)")
                continue
            }
            for url in urls {
                group.enter()
                stageTrackForNotification(url) { result in
                    if let name = result {
                        print("✅ Staged [\(season.rawValue)]: \(url.lastPathComponent) → \(name)")
                    } else {
                        print("❌ Staging failed for \(url.lastPathComponent)")
                    }
                    group.leave()
                }
            }
        }
        group.notify(queue: .main) {
            print("🎵 All tracks staged.")
            completion?()
        }
    }

    /// Copies + trims source to Library/Sounds as a safe-named .caf file.
    /// Calls back on the main queue with the staged filename or nil.
    static func stageTrackForNotification(_ sourceURL: URL, completion: @escaping (String?) -> Void) {
        let cleanName = sanitizeFilename(sourceURL.deletingPathExtension().lastPathComponent) + ".caf"
        let destURL   = soundsDirectory.appendingPathComponent(cleanName)

        // Skip if already staged and source hasn't changed
        let srcSize  = (try? FileManager.default.attributesOfItem(atPath: sourceURL.path)[.size] as? Int) ?? -1
        let destSize = (try? FileManager.default.attributesOfItem(atPath: destURL.path)[.size] as? Int) ?? -2
        if srcSize == destSize && srcSize > 0 {
            DispatchQueue.main.async { completion(cleanName) }
            return
        }

        // Remove stale copy
        try? FileManager.default.removeItem(at: destURL)

        // Export via AVAssetExportSession — trims to maxNotificationDuration and writes .caf
        let asset = AVURLAsset(url: sourceURL)
        guard let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            // Fallback: plain copy if exporter unavailable
            do {
                let fallbackName = sanitizeFilename(sourceURL.deletingPathExtension().lastPathComponent)
                    + "." + sourceURL.pathExtension
                let fallbackURL = soundsDirectory.appendingPathComponent(fallbackName)
                try? FileManager.default.removeItem(at: fallbackURL)
                try FileManager.default.copyItem(at: sourceURL, to: fallbackURL)
                DispatchQueue.main.async { completion(fallbackName) }
            } catch {
                DispatchQueue.main.async { completion(nil) }
            }
            return
        }

        // Use .m4a output (AVAssetExportPresetAppleM4A → .m4a), rename dest to .m4a
        let m4aName = sanitizeFilename(sourceURL.deletingPathExtension().lastPathComponent) + ".m4a"
        let m4aURL  = soundsDirectory.appendingPathComponent(m4aName)
        try? FileManager.default.removeItem(at: m4aURL)

        exporter.outputURL       = m4aURL
        exporter.outputFileType  = .m4a
        exporter.shouldOptimizeForNetworkUse = false

        // Trim to first 28 seconds
        let duration    = asset.duration
        let trimEnd     = min(CMTimeGetSeconds(duration), maxNotificationDuration)
        exporter.timeRange = CMTimeRange(
            start: .zero,
            duration: CMTimeMakeWithSeconds(trimEnd, preferredTimescale: 600)
        )

        exporter.exportAsynchronously {
            DispatchQueue.main.async {
                if exporter.status == .completed {
                    completion(m4aName)
                } else {
                    print("Export error: \(exporter.error?.localizedDescription ?? "unknown")")
                    // Last-resort fallback: plain copy without trimming
                    let rawName = sanitizeFilename(sourceURL.deletingPathExtension().lastPathComponent)
                        + "." + sourceURL.pathExtension
                    let rawURL = soundsDirectory.appendingPathComponent(rawName)
                    try? FileManager.default.copyItem(at: sourceURL, to: rawURL)
                    completion(rawName)
                }
            }
        }
    }

    static func stagedURL(for filename: String) -> URL? {
        let direct = soundsDirectory.appendingPathComponent(filename)
        if FileManager.default.fileExists(atPath: direct.path) { return direct }
        // Try with sanitized name in case stored name differs
        let sanitized = soundsDirectory.appendingPathComponent(
            sanitizeFilename((filename as NSString).deletingPathExtension) + ".m4a"
        )
        if FileManager.default.fileExists(atPath: sanitized.path) { return sanitized }
        return nil
    }

    /// Returns the sanitized .m4a name that stageTrackForNotification will produce,
    /// so AlarmManager can store it before staging completes.
    static func stagedFilename(for sourceURL: URL) -> String {
        sanitizeFilename(sourceURL.deletingPathExtension().lastPathComponent) + ".m4a"
    }

    static func sanitizeFilename(_ name: String) -> String {
        let clean = name.unicodeScalars.compactMap { scalar -> Character? in
            let c = Character(scalar)
            if c.isLetter || c.isNumber { return c }
            if c == "_" || c == "-"     { return c }
            if c == " "                 { return "_" }
            return nil
        }
        let result = String(clean).trimmingCharacters(in: CharacterSet(charactersIn: "_-"))
        return result.isEmpty ? "alarm" : result
    }

    // MARK: - Playback

    private func play(url: URL) {
        stopAlarm()
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            player?.numberOfLoops = -1
            player?.play()
            isPlaying = true
            nowPlayingFile = url.lastPathComponent
        } catch {
            print("❌ Audio playback error: \(error)")
        }
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
        nowPlayingFile = nil
    }
}
