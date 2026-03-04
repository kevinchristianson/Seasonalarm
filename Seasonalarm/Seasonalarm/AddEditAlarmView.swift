import SwiftUI
import AVFoundation

struct AddEditAlarmView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var alarmManager: AlarmManager
    @EnvironmentObject var theme: SeasonTheme

    var existingAlarm: Alarm? = nil

    @State private var selectedTime = Date()
    @State private var label = ""
    @State private var repeatDays: Set<Weekday> = []
    @State private var isEnabled = true
    @State private var systemVolumeLow = false
    @State private var volumeObserver: NSKeyValueObservation?

    private var isEditing: Bool { existingAlarm != nil }

    var body: some View {
        ZStack {
            // Blurred seasonal background
            SeasonalBackground(season: theme.season)
                .ignoresSafeArea()
                .blur(radius: 8)

            Color.black.opacity(0.45).ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Custom header — no NavigationView so no UIKit oval interference ──
                HStack {
                    Button { dismiss() } label: {
                        Text("Cancel")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.red.opacity(0.9))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.red.opacity(0.12))
                                    .overlay(RoundedRectangle(cornerRadius: 8)
                                        .strokeBorder(Color.red.opacity(0.3), lineWidth: 1))
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 8)

                    Spacer()

                    Text(isEditing ? "Edit Alarm" : "New Alarm")
                        .font(.system(size: 17, weight: .semibold, design: .monospaced))
                        .foregroundStyle(theme.season.accentColor)

                    Spacer()

                    Button { save() } label: {
                        Text("Save")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color(red: 0.2, green: 0.85, blue: 0.4))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(red: 0.2, green: 0.85, blue: 0.4).opacity(0.12))
                                    .overlay(RoundedRectangle(cornerRadius: 8)
                                        .strokeBorder(Color(red: 0.2, green: 0.85, blue: 0.4).opacity(0.3), lineWidth: 1))
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 8)
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 12)

                PixelDivider(color: .white.opacity(0.15))

                // ── Content ──
                ScrollView {
                    VStack(spacing: 16) {

                        // Time wheel
                        sectionCard {
                            DatePicker("", selection: $selectedTime, displayedComponents: .hourAndMinute)
                                .datePickerStyle(.wheel)
                                .labelsHidden()
                                .colorScheme(.dark)
                                .frame(maxWidth: .infinity)
                        }

                        // Label
                        sectionCard(header: "LABEL") {
                            TextField("Alarm name (optional)", text: $label)
                                .pixelFont(14)
                                .foregroundStyle(.white)
                                .tint(theme.season.accentColor)
                                .colorScheme(.dark)
                        }

                        // Repeat days
                        sectionCard(header: "REPEAT") {
                            WeekdaySelectorView(selectedDays: $repeatDays, season: theme.season)
                        }

                        // Low volume warning
                        if systemVolumeLow {
                            sectionCard {
                                HStack(spacing: 14) {
                                    Image(systemName: "speaker.slash.fill")
                                        .font(.system(size: 22))
                                        .foregroundStyle(.orange)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("VOLUME IS LOW")
                                            .pixelFont(11, weight: .bold)
                                            .foregroundStyle(.orange)
                                        Text("Turn up your media volume so the alarm is audible.")
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundStyle(.white.opacity(0.7))
                                    }
                                }
                            }
                        }

                        // Seasonal sound note
                        sectionCard {
                            HStack(spacing: 14) {
                                Text(theme.season.emoji)
                                    .font(.system(size: 28))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("SEASONAL SOUND")
                                        .pixelFont(11, weight: .bold)
                                        .foregroundStyle(theme.season.accentColor)
                                    Text("Plays a random \(theme.season.rawValue) track when the alarm fires.")
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(.white.opacity(0.55))
                                }
                            }
                        }

                        // Delete
                        if isEditing {
                            Button(role: .destructive) {
                                if let id = existingAlarm?.id {
                                    alarmManager.deleteAlarm(id: id)
                                }
                                dismiss()
                            } label: {
                                Text("DELETE ALARM")
                                    .pixelFont(12, weight: .bold)
                                    .foregroundStyle(.red.opacity(0.85))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.red.opacity(0.12))
                                            .overlay(RoundedRectangle(cornerRadius: 12)
                                                .strokeBorder(Color.red.opacity(0.3), lineWidth: 1))
                                    )
                            }
                        }

                        Spacer(minLength: 32)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                }
            }
        }
        .onAppear {
            prefill()
            checkVolume()
            startVolumeObserver()
        }
        .onDisappear {
            volumeObserver?.invalidate()
            volumeObserver = nil
        }
    }

    @ViewBuilder
    private func sectionCard<Content: View>(header: String? = nil, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: header != nil ? 10 : 0) {
            if let header {
                Text(header)
                    .pixelFont(10, weight: .bold)
                    .foregroundStyle(.white.opacity(0.45))
                    .padding(.leading, 4)
            }
            content()
                .padding(16)
                .seasonCard(season: theme.season)
        }
    }

    private func checkVolume() {
        let vol = AVAudioSession.sharedInstance().outputVolume
        systemVolumeLow = vol < 0.2
        print("🔊 System output volume: \(Int(vol * 100))%")
    }

    private func startVolumeObserver() {
        let session = AVAudioSession.sharedInstance()
        try? session.setActive(true)
        volumeObserver = session.observe(\.outputVolume, options: [.new]) { _, change in
            DispatchQueue.main.async {
                let vol = change.newValue ?? session.outputVolume
                withAnimation(.easeInOut(duration: 0.3)) {
                    systemVolumeLow = vol < 0.2
                }
            }
        }
    }

    private func prefill() {
        guard let alarm = existingAlarm else { return }
        var comps = DateComponents()
        comps.hour   = alarm.hour
        comps.minute = alarm.minute
        selectedTime = Calendar.current.date(from: comps) ?? Date()
        label        = alarm.label
        repeatDays   = alarm.repeatDays
        isEnabled    = alarm.isEnabled
    }

    private func save() {
        let cal    = Calendar.current
        let hour   = cal.component(.hour, from: selectedTime)
        let minute = cal.component(.minute, from: selectedTime)

        if var existing = existingAlarm {
            existing.label      = label
            existing.hour       = hour
            existing.minute     = minute
            existing.repeatDays = repeatDays
            existing.isEnabled  = isEnabled
            alarmManager.updateAlarm(existing)
        } else {
            let alarm = Alarm(label: label, hour: hour, minute: minute,
                              repeatDays: repeatDays, isEnabled: true)
            alarmManager.addAlarm(alarm)
        }
        dismiss()
    }
}

// MARK: - WeekdaySelectorView

struct WeekdaySelectorView: View {
    @Binding var selectedDays: Set<Weekday>
    let season: Season

    var body: some View {
        HStack(spacing: 7) {
            ForEach(Weekday.allCases, id: \.id) { day in
                let selected = selectedDays.contains(day)
                Button {
                    if selected { selectedDays.remove(day) } else { selectedDays.insert(day) }
                } label: {
                    Text(day.shortName.uppercased())
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selected ? season.accentColor : Color.white.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .strokeBorder(
                                            selected ? season.accentColor : Color.white.opacity(0.2),
                                            lineWidth: 1
                                        )
                                )
                        )
                        .foregroundStyle(selected ? .black : .white.opacity(0.7))
                }
                .buttonStyle(.plain)
                .animation(.easeInOut(duration: 0.12), value: selected)
            }
        }
    }
}
