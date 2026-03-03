import SwiftUI
import Combine

/// Holds the active season and provides season-aware styling helpers.
/// Inject via .environmentObject(SeasonTheme()) at the root.
final class SeasonTheme: ObservableObject {
    @Published var season: Season = {
        let s = Season.current
        let month = Calendar.current.component(.month, from: Date())
        print("🌿 SeasonTheme init → \(s.rawValue) (month \(month), \(SeasonDetector.shared.isNorthernHemisphere ? "northern" : "southern") hemisphere)")
        return s
    }()

    private var locationObserver: AnyCancellable?

    init() {
        // Re-evaluate season if location updates (hemisphere may change)
        locationObserver = NotificationCenter.default
            .publisher(for: .seasonDetectorDidUpdate)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refresh() }
    }

    /// Call when the app becomes active to refresh if the season changed
    func refresh() {
        let s = Season.current
        print("🌿 SeasonTheme refresh → \(s.rawValue)")
        season = s
    }
}

// MARK: - View helpers

extension View {
    /// Styled pixel-art button look: bordered capsule with accent color
    func pixelButtonStyle(season: Season) -> some View {
        self
            .font(.system(size: 14, weight: .bold, design: .monospaced))
            .foregroundStyle(season.accentColor)
            .padding(.horizontal, 18)
            .padding(.vertical, 9)
            .background(
                Capsule()
                    .strokeBorder(season.accentColor, lineWidth: 2)
                    .background(Capsule().fill(season.accentColor.opacity(0.15)))
            )
    }

    /// Semi-transparent dark panel card
    func seasonCard(season: Season, cornerRadius: CGFloat = 16) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(season.overlayColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .strokeBorder(season.accentColor.opacity(0.3), lineWidth: 1)
                    )
            )
    }
}

// MARK: - PixelDivider

struct PixelDivider: View {
    var color: Color = .white.opacity(0.12)
    var body: some View {
        Rectangle()
            .fill(color)
            .frame(height: 1)
    }
}

// MARK: - Pixel font modifier

struct PixelFont: ViewModifier {
    let size: CGFloat
    let weight: Font.Weight
    func body(content: Content) -> some View {
        content.font(.system(size: size, weight: weight, design: .monospaced))
    }
}

extension View {
    func pixelFont(_ size: CGFloat, weight: Font.Weight = .regular) -> some View {
        modifier(PixelFont(size: size, weight: weight))
    }
}
