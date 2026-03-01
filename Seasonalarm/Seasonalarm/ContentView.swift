import SwiftUI

struct ContentView: View {
    @EnvironmentObject var alarmManager: AlarmManager
    @EnvironmentObject var audioManager: AudioManager
    @StateObject private var theme = SeasonTheme()

    var body: some View {
        ZStack {
            // Full-screen seasonal background
            SeasonalBackground(season: theme.season)
                .ignoresSafeArea()

            // Main content
            VStack(spacing: 0) {
                if audioManager.isPlaying && alarmManager.ringingAlarmId == nil {
                    // Banner only when audio plays without a ringing alarm (e.g. edge cases)
                    AlarmBannerView()
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                AlarmListView()
            }
            .padding(.top, safeAreaTop)

            // Full-screen alarm takeover
            if let ringingId = alarmManager.ringingAlarmId,
               let alarm = alarmManager.alarm(withId: ringingId) {
                AlarmScreen(alarm: alarm)
                    .environmentObject(theme)
                    .zIndex(100)
            }
        }
        .environmentObject(theme)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: audioManager.isPlaying)
        .animation(.easeInOut(duration: 0.3), value: alarmManager.ringingAlarmId)
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
            if let uiImage = UIImage(named: season.backgroundImageName) {
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

    private var fallbackColors: [Color] {
        switch season {
        case .spring: return [Color(hex: "#1a2e1a"), Color(hex: "#0d1a0d")]
        case .summer: return [Color(hex: "#0d2620"), Color(hex: "#071510")]
        case .fall:   return [Color(hex: "#2e1208"), Color(hex: "#1a0a04")]
        case .winter: return [Color(hex: "#0d1a2e"), Color(hex: "#060d1a")]
        }
    }
}

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
