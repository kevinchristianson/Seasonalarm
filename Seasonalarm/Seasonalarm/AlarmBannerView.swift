import SwiftUI
import Combine

struct AlarmBannerView: View {
    @EnvironmentObject var audioManager: AudioManager
    @EnvironmentObject var theme: SeasonTheme
    @State private var pulse = false
    @State private var shimmer = false

    private var season: Season { Season.current }

    var body: some View {
        HStack(spacing: 14) {
            // Pulsing emoji
            Text(season.emoji)
                .font(.system(size: 28))
                .scaleEffect(pulse ? 1.2 : 1.0)
                .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: pulse)
                .onAppear { pulse = true }

            VStack(alignment: .leading, spacing: 3) {
                Text("ALARM PLAYING")
                    .pixelFont(11, weight: .bold)
                    .foregroundStyle(season.accentColor)
                if let file = audioManager.nowPlayingFile {
                    Text((file as NSString).deletingPathExtension
                        .replacingOccurrences(of: "_", with: " ")
                        .uppercased())
                        .pixelFont(9)
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                }
            }

            Spacer()

            // Waveform
            MiniWaveform(color: season.accentColor)
                .frame(width: 36)

            // Stop button
            Button {
                audioManager.stopAlarm()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(.black)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(season.accentColor))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(season.overlayColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .strokeBorder(season.accentColor.opacity(0.6), lineWidth: 1.5)
                )
        )
        .shadow(color: season.accentColor.opacity(0.25), radius: 16, x: 0, y: 4)
        .padding(.horizontal, 16)
        .padding(.top, 6)
    }
}

// MARK: - MiniWaveform (moved here after SoundLibraryView was removed)

struct MiniWaveform: View {
    let color: Color
    @State private var animate = false
    private let heights: [CGFloat] = [8, 14, 10, 18, 12, 16, 9]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<heights.count, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: 3, height: animate ? heights[i] : heights[i] * 0.4)
                    .animation(
                        .easeInOut(duration: 0.4 + Double(i) * 0.05)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.07),
                        value: animate
                    )
            }
        }
        .onAppear { animate = true }
        .onDisappear { animate = false }
    }
}
