import SwiftUI

struct DashboardView: View {
    @State private var dashboard: Dashboard?
    @State private var recentSessions: [SessionListItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            if isLoading {
                ProgressView()
            } else if let dashboard = dashboard {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Stats cards
                        HStack(spacing: 16) {
                            StatCard(
                                title: "Total Races",
                                value: String(dashboard.totalRaces),
                                icon: "flag.checkered"
                            )
                            StatCard(
                                title: "Unique Tracks",
                                value: String(dashboard.totalTracks),
                                icon: "map"
                            )
                            StatCard(
                                title: "Unique Cars",
                                value: String(dashboard.totalCars),
                                icon: "car.2"
                            )
                            if let days = dashboard.careerSpanDays {
                                StatCard(
                                    title: "Career Days",
                                    value: String(days),
                                    icon: "calendar"
                                )
                            }
                        }

                        // Recent sessions — fetched from /api/v1/sessions,
                        // not included in the dashboard aggregate.
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Recent Sessions")
                                .font(.headline)
                            if recentSessions.isEmpty {
                                Text("No sessions yet")
                                    .foregroundColor(.secondary)
                            } else {
                                List(recentSessions) { session in
                                    NavigationLink(destination: SessionDetailView(sessionId: session.id)) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(session.seriesName)
                                                .font(.subheadline)
                                                .fontWeight(.semibold)
                                            Text(session.trackName)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            Text(session.startTime.formatted(date: .abbreviated, time: .shortened))
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                                .frame(height: CGFloat(min(recentSessions.count * 60, 300)))
                            }
                        }
                    }
                    .padding()
                }
                .refreshable {
                    await loadDashboard()
                }
            } else if let error = errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 32))
                        .foregroundColor(.orange)
                    Text("Failed to load dashboard")
                        .font(.headline)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Button("Retry") {
                        Task {
                            await loadDashboard()
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .controlBackgroundColor))
            }
        }
        .task {
            await loadDashboard()
        }
    }

    private func loadDashboard() async {
        isLoading = true
        errorMessage = nil
        do {
            // Fire both concurrently — dashboard stats and recent sessions
            // come from different endpoints.
            async let dashTask = APIClient.shared.dashboard()
            async let sessionsTask = APIClient.shared.sessions(limit: 5, offset: 0, category: "all")
            dashboard = try await dashTask
            recentSessions = (try? await sessionsTask)?.sessions ?? []
        } catch {
            errorMessage = error.localizedDescription
            Log.error("Failed to load dashboard: \(error)")
        }
        isLoading = false
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(Color(hex: "#e53935"))
            Text(value)
                .font(.system(size: 20, weight: .bold))
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        // NSColor has no .secondarySystemBackground (UIKit-only). On macOS
        // .controlBackgroundColor is the standard "surface one layer above
        // the window" token — matches iOS's secondarySystemBackground intent.
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }
}

#Preview {
    DashboardView()
}
