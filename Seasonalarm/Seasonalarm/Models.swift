import Foundation
import SwiftUI

// MARK: - Season

enum Season: String, CaseIterable, Codable, Identifiable {
    case spring = "Spring"
    case summer = "Summer"
    case fall   = "Fall"
    case winter = "Winter"

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .spring: return "🌸"
        case .summer: return "☀️"
        case .fall:   return "🍂"
        case .winter: return "❄️"
        }
    }

    var folderName: String { rawValue }

    var backgroundImageName: String {
        switch self {
        case .spring: return "spring_bg"
        case .summer: return "summer_bg"
        case .fall:   return "fall_bg"
        case .winter: return "winter_bg"
        }
    }

    var accentColor: Color {
        switch self {
        case .spring: return Color(red: 0.72, green: 0.88, blue: 0.45)
        case .summer: return Color(red: 0.35, green: 0.85, blue: 0.72)
        case .fall:   return Color(red: 1.00, green: 0.65, blue: 0.22)
        case .winter: return Color(red: 0.60, green: 0.85, blue: 1.00)
        }
    }

    var overlayColor: Color {
        switch self {
        case .spring: return Color(red: 0.05, green: 0.12, blue: 0.05).opacity(0.72)
        case .summer: return Color(red: 0.02, green: 0.10, blue: 0.08).opacity(0.72)
        case .fall:   return Color(red: 0.12, green: 0.04, blue: 0.02).opacity(0.72)
        case .winter: return Color(red: 0.04, green: 0.08, blue: 0.15).opacity(0.72)
        }
    }

    var gradient: [String] {
        switch self {
        case .spring: return ["#A8EDAB", "#67C76B"]
        case .summer: return ["#FFD97D", "#F4A226"]
        case .fall:   return ["#F4A460", "#C0562B"]
        case .winter: return ["#A8D8F0", "#5BA3CC"]
        }
    }

    static var current: Season {
        let month = Calendar.current.component(.month, from: Date())
        switch month {
        case 3, 4, 5:   return .spring
        case 6, 7, 8:   return .summer
        case 9, 10, 11: return .fall
        default:         return .winter
        }
    }
}

// MARK: - Weekday

enum Weekday: Int, CaseIterable, Codable, Identifiable {
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday

    var id: Int { rawValue }

    var shortName: String {
        switch self {
        case .sunday:    return "Su"
        case .monday:    return "Mo"
        case .tuesday:   return "Tu"
        case .wednesday: return "We"
        case .thursday:  return "Th"
        case .friday:    return "Fr"
        case .saturday:  return "Sa"
        }
    }
}

// MARK: - Alarm

struct Alarm: Identifiable, Codable, Equatable {
    var id: String = UUID().uuidString
    var label: String
    var hour: Int
    var minute: Int
    var repeatDays: Set<Weekday>
    var isEnabled: Bool
    var createdAt: Date = Date()
    /// The track chosen when this alarm was last scheduled.
    /// Stored so the notification sound matches what AVAudioPlayer will play.
    var scheduledTrackName: String? = nil

    var timeString: String {
        let h = hour % 12 == 0 ? 12 : hour % 12
        let m = String(format: "%02d", minute)
        let period = hour < 12 ? "AM" : "PM"
        return "\(h):\(m) \(period)"
    }

    var repeatDescription: String {
        if repeatDays.isEmpty { return "Once" }
        if repeatDays.count == 7 { return "Every day" }
        let weekdays: Set<Weekday> = [.monday, .tuesday, .wednesday, .thursday, .friday]
        let weekend: Set<Weekday>  = [.saturday, .sunday]
        if repeatDays == weekdays { return "Weekdays" }
        if repeatDays == weekend  { return "Weekends" }
        return repeatDays
            .sorted { $0.rawValue < $1.rawValue }
            .map { $0.shortName }
            .joined(separator: " ")
    }
}
