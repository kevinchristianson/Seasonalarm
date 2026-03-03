import UIKit

/// Switches the app icon to match the current season.
/// Requires alternate icon sets in Assets.xcassets named AppIcon-Summer,
/// AppIcon-Fall, AppIcon-Winter, and CFBundleAlternateIcons in Info.plist.
enum SeasonalIconManager {

    @MainActor
    static func updateIconForCurrentSeason() {
        let season = Season.current
        let targetIcon = iconName(for: season)
        let currentIcon = UIApplication.shared.alternateIconName

        print("🎨 Icon check — season: \(season.rawValue), current icon: \(currentIcon ?? "primary"), target: \(targetIcon ?? "primary")")

        guard currentIcon != targetIcon else {
            print("🎨 Icon already correct, skipping")
            return
        }

        guard UIApplication.shared.supportsAlternateIcons else {
            print("⚠️ Alternate icons not supported — check Info.plist CFBundleAlternateIcons entries")
            return
        }

        UIApplication.shared.setAlternateIconName(targetIcon) { error in
            if let error {
                print("⚠️ Icon switch failed: \(error.localizedDescription)")
                print("   Make sure AppIcon-\(season.rawValue) exists in Assets.xcassets and Info.plist")
            } else {
                print("🎨 Icon switched to \(targetIcon ?? "primary") (\(season.rawValue))")
            }
        }
    }

    /// nil = primary icon (Spring uses the default AppIcon)
    private static func iconName(for season: Season) -> String? {
        switch season {
        case .spring: return nil
        case .summer: return "AppIcon-Summer"
        case .fall:   return "AppIcon-Fall"
        case .winter: return "AppIcon-Winter"
        }
    }
}
