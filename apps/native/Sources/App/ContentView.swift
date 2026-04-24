import SwiftUI

enum Destination: String, CaseIterable {
    case dashboard = "Dashboard"
    case races = "Races"
    case moments = "Moments"
    case tracks = "Tracks"
    case cars = "Cars"
    case dna = "DNA"
    case when = "When"
    case safety = "Safety"
    case composure = "Composure"
    case debrief = "Debrief"
    case settings = "Settings"

    var icon: String {
        switch self {
        case .dashboard: return "gauge.with.dots.needle.bottom.50percent"
        case .races: return "flag.checkered"
        case .moments: return "sparkles"
        case .tracks: return "map"
        case .cars: return "car.2"
        // `dna` and `chat.left.quote` are NOT valid SF Symbol names (console
        // warnings: "No symbol named 'dna' found in system symbol set").
        // Using the closest valid matches: `atom` for driver DNA, and
        // `quote.bubble` for the debrief panel.
        case .dna: return "atom"
        case .when: return "calendar"
        case .safety: return "shield"
        case .composure: return "heart"
        case .debrief: return "quote.bubble"
        case .settings: return "gear"
        }
    }
}

struct ContentView: View {
    @State private var selectedDestination: Destination = .dashboard

    var body: some View {
        NavigationSplitView {
            List(Destination.allCases, id: \.self, selection: $selectedDestination) { dest in
                NavigationLink(value: dest) {
                    Label(dest.rawValue, systemImage: dest.icon)
                }
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 250)
        } detail: {
            detailView(for: selectedDestination)
                .navigationTitle(selectedDestination.rawValue)
        }
    }

    @ViewBuilder
    func detailView(for destination: Destination) -> some View {
        switch destination {
        case .dashboard:
            DashboardView()
        case .races:
            SessionsView()
        case .moments:
            PlaceholderView(title: "Moments", subtitle: "Highlight detection coming soon")
        case .tracks:
            PlaceholderView(title: "Tracks", subtitle: "Track library coming soon")
        case .cars:
            PlaceholderView(title: "Cars", subtitle: "Car statistics coming soon")
        case .dna:
            PlaceholderView(title: "DNA", subtitle: "Driving analytics coming soon")
        case .when:
            PlaceholderView(title: "When", subtitle: "Historical trends coming soon")
        case .safety:
            PlaceholderView(title: "Safety", subtitle: "Safety ratings coming soon")
        case .composure:
            PlaceholderView(title: "Composure", subtitle: "Mental performance coming soon")
        case .debrief:
            PlaceholderView(title: "Debrief", subtitle: "AI debrief coming soon")
        case .settings:
            SettingsView()
        }
    }
}

struct PlaceholderView: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "hourglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Link("Visit web app", destination: URL(string: "https://prodrive.racecor.io")!)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

#Preview {
    ContentView()
}
