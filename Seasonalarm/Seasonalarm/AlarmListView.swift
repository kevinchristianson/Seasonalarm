import SwiftUI

struct AlarmListView: View {
    @EnvironmentObject var alarmManager: AlarmManager
    @EnvironmentObject var theme: SeasonTheme
    @State private var showingAddAlarm   = false
    @State private var editingAlarm: Alarm? = nil
    @State private var showingRebootWarning = false

    var sortedAlarms: [Alarm] {
        alarmManager.alarms.sorted { ($0.hour * 60 + $0.minute) < ($1.hour * 60 + $1.minute) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── Header ─────────────────────────────────────────────────────
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("ALARMS")
                        .font(.system(size: 28, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.8), radius: 2, x: 0, y: 1)
                        .shadow(color: .black.opacity(0.5), radius: 8)
                    Text(theme.season.emoji + " " + theme.season.rawValue.uppercased())
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.85))
                        .shadow(color: .black.opacity(0.7), radius: 4)
                }
                Spacer()
                // Info button — explains the reboot limitation
                Button {
                    showingRebootWarning = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                        .shadow(color: .black.opacity(0.5), radius: 3)
                }
                .padding(.trailing, 10)

                Button { showingAddAlarm = true } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(
                            Circle()
                                .fill(.black.opacity(0.35))
                                .overlay(Circle().strokeBorder(.white.opacity(0.5), lineWidth: 1.5))
                        )
                        .shadow(color: .black.opacity(0.3), radius: 4)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 12)

            PixelDivider(color: .white.opacity(0.2))

            if alarmManager.alarms.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(sortedAlarms) { alarm in
                            StretchDeleteRow(
                                onDelete: { alarmManager.deleteAlarm(id: alarm.id) }
                            ) {
                                AlarmCard(
                                    alarm: alarm,
                                    isRinging: alarmManager.ringingAlarmId == alarm.id
                                ) {
                                    if alarmManager.ringingAlarmId != alarm.id {
                                        editingAlarm = alarm
                                    }
                                }
                            }
                            .transition(.opacity.combined(with: .scale(scale: 0.96)))
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 14)
                    .padding(.bottom, 40)
                }
            }
        }
        .sheet(isPresented: $showingAddAlarm) {
            AddEditAlarmView().environmentObject(theme)
        }
        .sheet(item: $editingAlarm) { alarm in
            AddEditAlarmView(existingAlarm: alarm).environmentObject(theme)
        }
        .alert("About Background Audio", isPresented: $showingRebootWarning) {
            Button("Got it", role: .cancel) {}
        } message: {
            Text("""
                Seasonal Alarms plays silent background audio to keep itself alive overnight, which allows your full seasonal tracks to play without a 30-second limit.

                If your iPhone restarts overnight (e.g. during an iOS update), the app will need to relaunch before background audio resumes. In that case, your alarm notification will still appear on the lock screen — but only the short notification sound will play until you open the app.

                To be safe on evenings when an update is expected, open the app before going to sleep so it's running in the background.
                """)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 22) {
            Spacer()
            Text(theme.season.emoji).font(.system(size: 64))
            Text("NO ALARMS SET")
                .pixelFont(14, weight: .bold)
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.5), radius: 4)
            Text("Tap + to add your first\nseasonal alarm")
                .pixelFont(11)
                .foregroundStyle(.white.opacity(0.8))
                .shadow(color: .black.opacity(0.4), radius: 3)
                .multilineTextAlignment(.center)
            Button { showingAddAlarm = true } label: {
                Text("+ ADD ALARM").pixelButtonStyle(season: theme.season)
            }
            Spacer()
        }
        .padding()
    }
}

// MARK: - AlarmCard

struct AlarmCard: View {
    let alarm: Alarm
    let isRinging: Bool
    let onEdit: () -> Void

    @EnvironmentObject var alarmManager: AlarmManager
    @EnvironmentObject var theme: SeasonTheme
    @State private var ringPulse = false

    var body: some View {
        Button(action: onEdit) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    if isRinging {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(theme.season.accentColor)
                                .frame(width: 8, height: 8)
                                .scaleEffect(ringPulse ? 1.4 : 0.8)
                                .animation(
                                    .easeInOut(duration: 0.5).repeatForever(autoreverses: true),
                                    value: ringPulse
                                )
                            Text("RINGING")
                                .font(.system(size: 10, weight: .black, design: .monospaced))
                                .foregroundStyle(theme.season.accentColor)
                        }
                        .onAppear  { ringPulse = true  }
                        .onDisappear { ringPulse = false }
                    }

                    Text(alarm.timeString)
                        .font(.system(size: 48, weight: .black, design: .monospaced))
                        .foregroundStyle(
                            isRinging ? theme.season.accentColor
                            : alarm.isEnabled ? .white
                            : .white.opacity(0.3)
                        )
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)

                    HStack(spacing: 8) {
                        if !alarm.label.isEmpty {
                            chipLabel(alarm.label, color: theme.season.accentColor.opacity(0.8))
                        }
                        chipLabel(alarm.repeatDescription, color: .white.opacity(0.4))
                    }
                }

                Spacer()

                if isRinging {
                    Button {
                        alarmManager.stopRinging()
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "stop.fill")
                                .font(.system(size: 18, weight: .bold))
                            Text("STOP")
                                .font(.system(size: 9, weight: .black, design: .monospaced))
                        }
                        .foregroundStyle(.black)
                        .frame(width: 56, height: 56)
                        .background(Circle().fill(theme.season.accentColor))
                        .shadow(color: theme.season.accentColor.opacity(0.5), radius: 8)
                    }
                    .buttonStyle(.plain)
                } else {
                    Toggle("", isOn: Binding(
                        get: { alarm.isEnabled },
                        set: { alarmManager.setAlarmEnabled(id: alarm.id, enabled: $0) }
                    ))
                    .labelsHidden()
                    .tint(theme.season.accentColor)
                }
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isRinging ? theme.season.accentColor.opacity(0.18) : theme.season.overlayColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(
                                isRinging ? theme.season.accentColor
                                : alarm.isEnabled ? theme.season.accentColor.opacity(0.45)
                                : Color.white.opacity(0.12),
                                lineWidth: isRinging ? 2 : 1.5
                            )
                    )
            )
            .shadow(color: isRinging ? theme.season.accentColor.opacity(0.3) : .clear, radius: 12)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.25), value: isRinging)
    }

    private func chipLabel(_ text: String, color: Color) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundStyle(color)
    }
}
