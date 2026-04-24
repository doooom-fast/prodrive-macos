import SwiftUI

/// Native macOS dashboard mapped directly to the web `/drive/dashboard`
/// structure (not a reinterpretation):
///
///   ┌ DataStrip: RACES / LAPS / SPORTS CAR + sparkline+badge / FORMULA +
///   │            sparkline+badge / SPAN / TRACKS / CARS ────────────────┐
///   │                                                                   │
///   ├ HStack(main 3fr | sidebar 1fr) ────────────────────────────────── ┤
///   │  ┌ Main column ───────────────────────────┐  ┌ Sidebar ────────┐ │
///   │  │ Tabs: Performance / Next Race / Prev   │  │ Tracks / Cars   │ │
///   │  │ ┌ ShouldYouRacePanel (advisory) ─────┐ │  │ ┌ Rank list ──┐ │ │
///   │  │ ┌ Strengths / Watch Out panel ──────┐ │  │ │ 1 track card │ │ │
///   │  │ ┌ 3-viz grid ────────────────────── ┐│  │ │ 2 ...        │ │ │
///   │  │ │ Heatmap │ Schedule │ DNA radar   ││  │ │ ...          │ │ │
///   │  └────────────────────────────────────┘ │  │ └──────────────┘ │ │
///   │                                           │  └─────────────────┘ │
///   └───────────────────────────────────────────────────────────────────┘
///
/// Everything I previously built (Hero, big iRating cards, StatTile rows,
/// bottom 2x2 panels) has been removed — those were inventions, not
/// features of the product.
struct DashboardView: View {
    @EnvironmentObject var authManager: AuthManager

    @State private var dashboard: Dashboard?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedTab: DashboardTab = .performance

    var body: some View {
        ZStack {
            // No local ThemedBackgroundView — the signed-in root
            // (ContentView) owns it so the image extends behind the
            // sidebar too. The dashboard just sits on top.
            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 0) {
                    mainColumn
                        .frame(maxWidth: .infinity)

                    Rectangle()
                        .fill(Palette.borderSubtle)
                        .frame(width: 1)

                    SidebarTabs(
                        tracks: dashboard?.topTracks ?? [],
                        cars: dashboard?.topCars ?? []
                    )
                    .frame(width: 320)
                }
                .frame(maxHeight: .infinity)

                // DataStrip sits at the bottom of the detail view as a
                // persistent stats footer — same role the web uses it
                // for up top, just reading as a "status bar" in the
                // native app's Mac-idiom layout.
                DataStrip(
                    dashboard: dashboard,
                    safetyRating: dashboard?.safetyRating
                )
            }

            if isLoading && dashboard == nil {
                ProgressView().controlSize(.large)
            } else if dashboard == nil, let msg = errorMessage {
                errorOverlay(msg)
            }
        }
        .task { await load() }
    }

    // MARK: - Main column

    @ViewBuilder
    private var mainColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 14) {
                DashboardTabs(selection: $selectedTab)
                Spacer()
                toolbarLink(label: "Import", icon: "arrow.up")
                toolbarLink(label: "Download", icon: "arrow.down")
            }
            .padding(.horizontal, 20)
            .frame(height: 44)

            Divider().overlay(Palette.borderSubtle)

            ScrollView {
                Group {
                    switch selectedTab {
                    case .performance:
                        performanceContent
                    case .nextRace:
                        placeholderTab(title: "Next Race",
                                       subtitle: "AI-ranked race suggestions",
                                       icon: "flag")
                    case .previous:
                        placeholderTab(title: "Previous Races",
                                       subtitle: "Chronological race history",
                                       icon: "clock.arrow.circlepath")
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 30)
            }
            .refreshable { await load() }
        }
    }

    @ViewBuilder
    private var performanceContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            ShouldYouRacePanel(
                verdict: .unknown,
                title: "Not enough data",
                reason: "Add a few more races to get a race-now advisory."
            )

            StrengthsWatchOutPanel(
                strengths: .init(
                    label: "STRENGTHS",
                    tint: Palette.success,
                    window: "Coming soon",
                    footnote: nil,
                    summary: "Time-of-day and day-of-week performance insights will appear once enough race data is imported.",
                    bullets: []
                ),
                watchOut: .init(
                    label: "WATCH OUT",
                    tint: Palette.brand,
                    window: "Coming soon",
                    footnote: nil,
                    summary: "Incident hotspots and risk windows will be surfaced here.",
                    bullets: []
                )
            )

            HStack(alignment: .top, spacing: 14) {
                VizPlaceholder(title: "Race Calendar", subtitle: "Incidents", icon: "calendar")
                VizPlaceholder(title: "Race Schedule", subtitle: "Incidents", icon: "clock")
                VizPlaceholder(title: "Driver DNA", subtitle: nil, icon: "atom")
            }
        }
    }

    private func placeholderTab(title: String, subtitle: String, icon: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundColor(Palette.textMuted)
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Palette.textSecondary)
            Text(subtitle)
                .font(.system(size: 12))
                .foregroundColor(Palette.textDim)
            Text("Coming in a later pass — this tab isn't populated in the native app yet.")
                .font(.system(size: 11))
                .foregroundColor(Palette.textMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: 420)
        .panel()
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private func toolbarLink(label: String, icon: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 10, weight: .semibold))
            Text(label).font(.system(size: 11, weight: .medium))
        }
        .foregroundColor(Palette.textDim)
    }

    // MARK: - Error / loading

    private func errorOverlay(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 28))
                .foregroundColor(Palette.warning)
            Text("Can't load your dashboard")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Palette.textPrimary)
            Text(message)
                .font(.caption)
                .foregroundColor(Palette.textDim)
                .multilineTextAlignment(.center)
            Button("Retry") { Task { await load() } }
                .buttonStyle(.borderedProminent)
                .tint(Palette.brand)
        }
        .frame(maxWidth: 400)
        .panel()
        .padding(40)
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            dashboard = try await APIClient.shared.dashboard()
        } catch {
            errorMessage = error.localizedDescription
            Log.error("Failed to load dashboard: \(error)")
        }
        isLoading = false
    }
}

#Preview {
    DashboardView()
        .environmentObject(AuthManager())
        .frame(width: 1400, height: 900)
}
