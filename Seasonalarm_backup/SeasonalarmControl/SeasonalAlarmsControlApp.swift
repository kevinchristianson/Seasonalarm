import SwiftUI
import WidgetKit

@main
struct SeasonalAlarmsControlBundle: WidgetBundle {
    var body: some Widget {
        if #available(iOS 18.0, *) {
            SeasonalAlarmsControlWidget()
        }
    }
}
