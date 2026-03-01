import SwiftUI
import Combine

/// Full-screen alarm UI — appears over everything when an alarm is ringing,
/// matching the Clock app's lock screen experience.
struct AlarmScreen: View {
    let alarm: Alarm
    @EnvironmentObject var alarmManager: AlarmManager
    @EnvironmentObject var theme: SeasonTheme

    @State private var currentTime = Date()
    @State private var slideOffset: CGFloat = 0
    @State private var slideDragging = false
    @State private var pulse = false

    private let slideTrackWidth: CGFloat = 300
    private let slideKnobWidth:  CGFloat = 64
    private var slideMax: CGFloat { slideTrackWidth - slideKnobWidth - 8 }

    let clock = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            // Seasonal background with stronger dark overlay for lock-screen feel
            SeasonalBackground(season: theme.season)
                .ignoresSafeArea()
            Color.black.opacity(0.55).ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Season emoji — pulsing
                Text(theme.season.emoji)
                    .font(.system(size: 52))
                    .scaleEffect(pulse ? 1.12 : 0.95)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulse)
                    .onAppear { pulse = true }

                Spacer().frame(height: 20)

                // Current time (large, like Clock app)
                Text(timeString)
                    .font(.system(size: 88, weight: .thin, design: .default))
                    .foregroundStyle(.white)
                    .monospacedDigit()

                // Alarm label
                Text(alarm.label.isEmpty ? "Alarm" : alarm.label)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white.opacity(0.75))
                    .padding(.top, 4)

                Spacer()

                // Snooze button — big orange pill like Clock
                Button {
                    alarmManager.snoozeAlarm(id: alarm.id)
                } label: {
                    Text("Snooze")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 64)
                        .background(Capsule().fill(theme.season.accentColor))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 32)

                Spacer().frame(height: 20)

                // Slide to stop — matches Clock app's slider
                slideToStop

                Spacer().frame(height: 60)
            }
        }
        .onReceive(clock) { _ in currentTime = Date() }
        .transition(.opacity.animation(.easeInOut(duration: 0.3)))
    }

    // MARK: - Slide to stop control

    private var slideToStop: some View {
        ZStack(alignment: .leading) {
            // Track
            Capsule()
                .fill(Color.white.opacity(0.15))
                .frame(width: slideTrackWidth, height: slideKnobWidth)
                .overlay(
                    Text("slide to stop")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white.opacity(slideDragging ? 0.2 : 0.6))
                        .offset(x: 20)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .animation(.easeInOut(duration: 0.15), value: slideDragging)
                )

            // Knob
            Circle()
                .fill(.white)
                .frame(width: slideKnobWidth, height: slideKnobWidth)
                .overlay(
                    Image(systemName: "stop.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.black)
                )
                .offset(x: max(0, min(slideMax, slideOffset)) + 4)
                .shadow(color: .black.opacity(0.2), radius: 4)
                .gesture(
                    DragGesture()
                        .onChanged { v in
                            slideDragging = true
                            slideOffset = v.translation.width
                        }
                        .onEnded { v in
                            if slideOffset >= slideMax * 0.85 {
                                // Completed — stop alarm
                                withAnimation(.easeOut(duration: 0.15)) { slideOffset = slideMax }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                    alarmManager.stopRinging()
                                }
                            } else {
                                // Snap back
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                    slideOffset = 0
                                    slideDragging = false
                                }
                            }
                        }
                )
                .animation(.interactiveSpring(), value: slideOffset)
        }
        .frame(width: slideTrackWidth)
    }

    // MARK: - Helpers

    private var timeString: String {
        let f = DateFormatter()
        f.dateFormat = "h:mm"
        return f.string(from: currentTime)
    }
}
