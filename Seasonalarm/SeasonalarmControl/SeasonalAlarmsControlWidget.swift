import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Intent

struct OpenSeasonalAlarmsIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Seasonal Alarms"
    static var description = IntentDescription("Opens the Seasonal Alarms app.")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        return .result()
    }
}

// MARK: - Control Widget (iOS 18+)

@available(iOS 18.0, *)
struct SeasonalAlarmsControlWidget: ControlWidget {
    static let kind = "com.seasonalarm.controlwidget"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(
            kind: Self.kind,
            provider: Provider()
        ) { _ in
            ControlWidgetButton(action: OpenSeasonalAlarmsIntent()) {
                Label("Alarms", image: "WidgetIcon")
            }
        }
        .displayName("Seasonal Alarms")
        .description("Open the Seasonal Alarms app.")
    }
}

// MARK: - Provider

@available(iOS 18.0, *)
struct Provider: ControlValueProvider {
    var previewValue: Bool { true }
    func currentValue() async throws -> Bool { true }
}
