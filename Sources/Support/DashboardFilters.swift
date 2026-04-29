import Foundation

/// Dashboard filter prefs, mirrored from the web app's `?context=`
/// and `?license=` URL parameters and from the iOS app's
/// equivalent enums.
///
/// - **Context** (`race` / `practice`): which class of session
///   feeds every calc on the dashboard. Default `race`.
/// - **License** (`all` + the five iRacing categories): slices
///   the dashboard to a single discipline. Default `all`.
///
/// `road` is the legacy code for what iRacing now calls "Sports
/// Car" (renamed in 2024 S2). Internal codes stay as `road`; only
/// display labels say "Sports Car". Same convention web codifies
/// in `server-design-system` skill.
enum DashboardContext: String, CaseIterable {
    case race
    case practice

    /// Plural label ("Races" / "Practices") for picker segments,
    /// titles, and any UI where a noun reads better in plural.
    var displayName: String {
        return noun(plural: true).capitalized
    }

    /// Singular vs plural noun for race-vs-practice copy. So empty
    /// states ("No <noun> yet"), progress strings, and any other
    /// human copy can render the right form regardless of which
    /// context is active.
    func noun(plural: Bool) -> String {
        switch self {
        case .race:     return plural ? "races" : "race"
        case .practice: return plural ? "practices" : "practice"
        }
    }
}

enum DashboardLicense: String, CaseIterable {
    case all
    case road
    case oval
    case dirt_road
    case dirt_oval
    case formula

    var displayName: String {
        switch self {
        case .all:        return "All Licenses"
        case .road:       return "Sports Car"
        case .oval:       return "Oval"
        case .dirt_road:  return "Dirt Road"
        case .dirt_oval:  return "Dirt Oval"
        case .formula:    return "Formula"
        }
    }
}

/// UserDefaults keys + thin accessors. View code uses
/// `@AppStorage(...)` (re-renders on change); non-view code
/// (DashboardPoller) reads `current()` synchronously each tick.
enum DashboardFilterPrefs {
    static let contextKey = "dashboard.context"
    static let licenseKey = "dashboard.license"

    static func current() -> (context: DashboardContext, license: DashboardLicense) {
        let ctx = UserDefaults.standard.string(forKey: contextKey)
            .flatMap(DashboardContext.init(rawValue:)) ?? .race
        let lic = UserDefaults.standard.string(forKey: licenseKey)
            .flatMap(DashboardLicense.init(rawValue:)) ?? .all
        return (ctx, lic)
    }
}
