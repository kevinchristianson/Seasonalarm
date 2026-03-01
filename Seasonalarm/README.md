# Seasonal Alarms — iOS App

A Clock-style alarm app that plays a **random track from the current season's folder** when each alarm fires.

---

## Project Setup in Xcode

1. **Create a new Xcode project**
   - File → New → Project → iOS → App
   - Product Name: `SeasonalAlarms`
   - Interface: **SwiftUI**
   - Language: **Swift**
   - Uncheck "Include Tests" (optional)

2. **Add all `.swift` source files**
   - Drag all the `.swift` files from this folder into the Xcode project navigator
   - Make sure "Copy items if needed" is checked
   - Target: SeasonalAlarms ✓

3. **Configure Info.plist**
   - In Xcode, open your `Info.plist`
   - Add the following keys:

   | Key | Type | Value |
   |-----|------|-------|
   | `UIBackgroundModes` | Array | `audio`, `fetch` |
   | `UIFileSharingEnabled` | Boolean | YES |
   | `LSSupportsOpeningDocumentsInPlace` | Boolean | YES |

4. **Add Background Modes capability**
   - Project → Target → Signing & Capabilities → + Capability → Background Modes
   - Enable: ☑ Audio, AirPlay, and Picture in Picture
   - Enable: ☑ Background fetch

5. **Add User Notifications capability** (usually auto-included, but confirm)

6. **Build & Run** on a device or simulator (iOS 16+)

---

## How Seasonal Tracks Work

The app looks for audio files in your app's Documents directory, organized by season:

```
Documents/
├── Spring/     ← e.g. birds_morning.mp3, rain_light.m4a
├── Summer/     ← e.g. beach_waves.mp3, cicadas.m4a
├── Fall/       ← e.g── wind_leaves.mp3, fireplace.m4a
└── Winter/     ← e.g. snowfall.mp3, christmas_bells.m4a
```

**Adding tracks (iTunes File Sharing / Files app):**
1. Open the **Files** app on your iPhone
2. Browse → On My iPhone → Seasonal Alarms
3. You'll see four folders: Spring, Summer, Fall, Winter
4. Copy your `.mp3`, `.m4a`, `.aac`, `.wav`, or `.aiff` files into the appropriate folder

**Supported formats:** MP3, M4A, AAC, WAV, AIFF, CAF

---

## How the App Decides Which Track to Play

- The season is determined by the **calendar month when the alarm fires** (not when it's created):
  - Spring: March–May
  - Summer: June–August
  - Fall: September–November
  - Winter: December–February
- A track is chosen **at random** from that season's folder each time the alarm goes off.
- If no tracks are found for the current season, the system notification sound plays as a fallback.

---

## Alarm Behavior

| State | Behavior |
|-------|----------|
| App in foreground | Plays seasonal audio immediately + shows banner |
| App in background | Delivers notification; opens app + plays when tapped |
| Screen locked | Delivers notification; opens app + plays when unlocked/tapped |

> **Note:** True background audio (playing before the user interacts) requires the `audio` background mode, which Apple may flag during App Store review unless your app is genuinely a music/alarm app. The current implementation is designed to be App Store compliant.

---

## Snooze & Stop

- **Stop:** Tap the X in the in-app banner, or use the "Stop Alarm" notification action
- **Snooze:** Use the "Snooze 9 min" notification action — the alarm fires again in 9 minutes

---

## Files Overview

| File | Purpose |
|------|---------|
| `SeasonalAlarmsApp.swift` | App entry point, wires up AppDelegate |
| `AppDelegate.swift` | Handles notification delivery and audio session |
| `Models.swift` | `Alarm`, `Season`, `Weekday` data types |
| `AlarmManager.swift` | Alarm CRUD, persistence, notification scheduling |
| `AudioManager.swift` | Random track selection and AVAudioPlayer playback |
| `ContentView.swift` | Tab container with active alarm overlay |
| `AlarmListView.swift` | Main alarm list (like Clock app) |
| `AddEditAlarmView.swift` | Create/edit alarm sheet with time picker + repeat days |
| `SoundLibraryView.swift` | Browse tracks per season, preview playback |
| `AlarmBannerView.swift` | In-app banner shown while alarm is playing |
