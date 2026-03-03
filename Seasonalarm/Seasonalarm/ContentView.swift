import SwiftUI

struct ContentView: View {
    @EnvironmentObject var alarmManager: AlarmManager
    @EnvironmentObject var audioManager: AudioManager
    @StateObject private var theme = SeasonTheme()

    var body: some View {
        ZStack {
            // Seasonal background fills everything
            SeasonalBackground(season: theme.season)
                .ignoresSafeArea()

            // Main alarm list
            VStack(spacing: 0) {
                AlarmBannerView()
                    .opacity(audioManager.isPlaying && alarmManager.ringingAlarmId == nil ? 1 : 0)
                    .frame(height: audioManager.isPlaying && alarmManager.ringingAlarmId == nil ? nil : 0)
                    .clipped()
                AlarmListView()
            }
            .padding(.top, safeAreaTop)

            // Full-screen alarm takeover when ringing
            if let ringingId = alarmManager.ringingAlarmId,
               let alarm = alarmManager.alarm(withId: ringingId) {
                AlarmScreen(alarm: alarm)
                    .environmentObject(theme)
                    .ignoresSafeArea()
                    .zIndex(100)
            }
        }
        .environmentObject(theme)
        .animation(.easeInOut(duration: 0.35), value: alarmManager.ringingAlarmId)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            theme.refresh()
        }
    }

    private var safeAreaTop: CGFloat {
        (UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.safeAreaInsets.top) ?? 0
    }
}

// MARK: - SeasonalBackground

struct SeasonalBackground: View {
    let season: Season

    var body: some View {
        ZStack {
            if let uiImage = loadBackground(for: season) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .id(season.id)
            } else {
                LinearGradient(colors: fallbackColors, startPoint: .top, endPoint: .bottom)
            }
            RadialGradient(
                gradient: Gradient(colors: [.clear, .black.opacity(0.4)]),
                center: .center,
                startRadius: UIScreen.main.bounds.width * 0.3,
                endRadius: UIScreen.main.bounds.width * 1.2
            )
        }
        .animation(.easeInOut(duration: 1.0), value: season)
    }

    private func loadBackground(for season: Season) -> UIImage? {
        let name = season.backgroundImageName
        // 1. Asset catalog (preferred — handles @2x/@3x automatically)
        if let img = UIImage(named: name) { return img }
        // 2. Direct bundle path — for images added to the project without an asset catalog entry
        let extensions = ["png", "jpg", "jpeg"]
        for ext in extensions {
            if let url = Bundle.main.url(forResource: name, withExtension: ext),
               let img = UIImage(contentsOfFile: url.path) {
                print("📸 Loaded \(name) from bundle path (.\(ext))")
                return img
            }
        }
        print("⚠️ No background image found for \(season.rawValue) — using gradient fallback")
        return nil
    }

    private var fallbackColors: [Color] {
        switch season {
        case .spring: return [Color(hex: "#1a2e1a"), Color(hex: "#0d1a0d")]
        case .summer: return [Color(hex: "#0d2620"), Color(hex: "#071510")]
        case .fall:   return [Color(hex: "#2e1208"), Color(hex: "#1a0a04")]
        case .winter: return [Color(hex: "#0d1a2e"), Color(hex: "#060d1a")]
        }
    }
}

// MARK: - Color hex init

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
