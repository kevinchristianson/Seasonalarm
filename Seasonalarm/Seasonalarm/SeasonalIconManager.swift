import UIKit

/// Switches the app icon to match the current season.
/// Requires four alternate icon sets registered in Info.plist.
enum SeasonalIconManager {

    /// Call this whenever the app becomes active so the icon stays in sync.
    @MainActor
    static func updateIconForCurrentSeason() {
        let season = Season.current
        let targetIcon = iconName(for: season)
        let currentIcon = UIApplication.shared.alternateIconName

        // No-op if already correct (avoids the "icon changed" system alert spam)
        guard currentIcon != targetIcon else { return }

        UIApplication.shared.setAlternateIconName(targetIcon) { error in
            if let error {
                print("⚠️ Icon switch failed for \(season.rawValue): \(error.localizedDescription)")
            } else {
                print("🎨 App icon switched to \(targetIcon ?? "primary") for \(season.rawValue)")
            }
        }
    }

    /// nil = primary icon (used for spring so the default icon is the spring one)
    private static func iconName(for season: Season) -> String? {
        switch season {
        case .spring: return nil              // Primary icon in Assets.xcassets
        case .summer: return "AppIcon-Summer"
        case .fall:   return "AppIcon-Fall"
        case .winter: return "AppIcon-Winter"
        }
    }
}
