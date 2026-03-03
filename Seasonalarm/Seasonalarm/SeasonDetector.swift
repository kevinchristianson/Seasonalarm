import Foundation
import CoreLocation

/// Determines the current astronomical season based on the device's hemisphere.
/// Uses precise equinox/solstice dates rather than calendar month boundaries.
final class SeasonDetector: NSObject, CLLocationManagerDelegate {

    static let shared = SeasonDetector()

    private let locationManager = CLLocationManager()
    /// Positive = northern hemisphere, negative = southern. nil = unknown (defaults to northern).
    private(set) var latitude: Double? = UserDefaults.standard.object(forKey: "lastLatitude") as? Double

    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
    }

    /// Request location permission and a single fix. Call at app launch.
    func requestLocation() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()
        default:
            break
        }
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        latitude = loc.coordinate.latitude
        UserDefaults.standard.set(latitude, forKey: "lastLatitude")
        print("🌍 Location updated: latitude \(String(format: "%.2f", loc.coordinate.latitude)) → \(isNorthernHemisphere ? "Northern" : "Southern") hemisphere")
        locationManager.stopUpdatingLocation()
        // Notify SeasonTheme to refresh
        NotificationCenter.default.post(name: .seasonDetectorDidUpdate, object: nil)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("🌍 Location failed: \(error.localizedDescription) — using cached or default hemisphere")
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse ||
           manager.authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        }
    }

    // MARK: - Season calculation

    var isNorthernHemisphere: Bool {
        (latitude ?? 1.0) >= 0  // default northern if unknown
    }

    /// The current astronomical season for the device's hemisphere.
    static var current: Season {
        shared.seasonFor(date: Date())
    }

    func seasonFor(date: Date) -> Season {
        let year = Calendar.current.component(.year, from: date)
        let northernSeason = northernSeasonFor(date: date, year: year)

        if isNorthernHemisphere {
            return northernSeason
        } else {
            // Southern hemisphere: flip by 2 seasons
            return northernSeason.opposite
        }
    }

    // MARK: - Equinox / solstice computation
    //
    // Uses the algorithm from Jean Meeus "Astronomical Algorithms" (simplified).
    // Accurate to within ~15 minutes for dates 1900–2100.

    private func northernSeasonFor(date: Date, year: Int) -> Season {
        let springEquinox  = equinoxSolstice(year: year, event: .marchEquinox)
        let summerSolstice = equinoxSolstice(year: year, event: .juneSolstice)
        let fallEquinox    = equinoxSolstice(year: year, event: .septemberEquinox)
        let winterSolstice = equinoxSolstice(year: year, event: .decemberSolstice)

        switch date {
        case ..<springEquinox:
            // Before March equinox — still winter (started last December)
            return .winter
        case springEquinox..<summerSolstice:
            return .spring
        case summerSolstice..<fallEquinox:
            return .summer
        case fallEquinox..<winterSolstice:
            return .fall
        default:
            return .winter
        }
    }

    private enum SolarEvent { case marchEquinox, juneSolstice, septemberEquinox, decemberSolstice }

    /// Returns the UTC Date of a solstice/equinox for a given year.
    private func equinoxSolstice(year: Int, event: SolarEvent) -> Date {
        // Meeus Table 27.a — JDE of mean equinox/solstice
        let y = Double(year - 2000) / 1000.0

        let JDE0: Double
        switch event {
        case .marchEquinox:
            JDE0 = 2451623.80984 + 365242.37404*y + 0.05169*y*y - 0.00411*y*y*y - 0.00057*y*y*y*y
        case .juneSolstice:
            JDE0 = 2451716.56767 + 365241.62603*y + 0.00325*y*y + 0.00888*y*y*y - 0.00030*y*y*y*y
        case .septemberEquinox:
            JDE0 = 2451810.21715 + 365242.01767*y - 0.11575*y*y + 0.00337*y*y*y + 0.00078*y*y*y*y
        case .decemberSolstice:
            JDE0 = 2451900.05952 + 365242.74049*y - 0.06223*y*y - 0.00823*y*y*y + 0.00032*y*y*y*y
        }

        // Convert Julian Day Number to Unix timestamp
        // JD 2440587.5 = January 1, 1970 00:00:00 UTC
        let unixTime = (JDE0 - 2440587.5) * 86400.0
        return Date(timeIntervalSince1970: unixTime)
    }
}

extension Season {
    /// The opposite season (for southern hemisphere)
    var opposite: Season {
        switch self {
        case .spring: return .fall
        case .summer: return .winter
        case .fall:   return .spring
        case .winter: return .summer
        }
    }
}

extension Notification.Name {
    static let seasonDetectorDidUpdate = Notification.Name("SeasonDetectorDidUpdate")
}
