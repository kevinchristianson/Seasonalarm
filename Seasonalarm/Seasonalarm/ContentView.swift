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
        .task {
            // Wait until the UI is fully rendered and interactive before
            // attempting the icon switch. Launch transaction callbacks
            // (didFinishLaunching, sceneDidBecomeActive, etc.) are too early —
            // SpringBoard rejects the XPC call with EAGAIN/NSUserCancelledError.
            try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
            await MainActor.run {
                SeasonalIconManager.updateIconForCurrentSeason()
            }
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

        // 1. Asset catalog
        if let img = UIImage(named: name) {
            print("📸 [\(season.rawValue)] loaded from asset catalog")
            return img
        }

        // 2. Direct bundle path — case-insensitive extension search
        let extensions = ["png", "PNG", "jpg", "JPG", "jpeg", "JPEG"]
        for ext in extensions {
            if let url = Bundle.main.url(forResource: name, withExtension: ext),
               let img = UIImage(contentsOfFile: url.path) {
                print("📸 [\(season.rawValue)] loaded from bundle: \(name).\(ext)")
                return img
            }
        }

        // 3. Scan the bundle root for any file starting with the image name
        //    (catches capitalisation differences like Spring_bg.PNG)
        if let bundleURL = Bundle.main.resourceURL,
           let files = try? FileManager.default.contentsOfDirectory(
               at: bundleURL, includingPropertiesForKeys: nil
           ) {
            let imageFiles = files.filter { url in
                let lower = url.lastPathComponent.lowercased()
                return lower.hasPrefix(name.lowercased()) &&
                       ["png","jpg","jpeg"].contains(url.pathExtension.lowercased())
            }
            print("📸 [\(season.rawValue)] bundle scan found: \(imageFiles.map(\.lastPathComponent))")
            if let match = imageFiles.first, let img = UIImage(contentsOfFile: match.path) {
                return img
            }
        }

        print("⚠️ [\(season.rawValue)] no background image found — check the file is added to the Seasonalarm target")
        print("   Expected asset name: \"\(name)\" — verify in Assets.xcassets or project navigator")
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
