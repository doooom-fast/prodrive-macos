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

    /// Single source of truth for the dashboard data is now the
    /// shared `DashboardPoller` — it fetches on an interval, publishes
    /// on the main actor, and fires notifications for new moments/
    /// results without us having to do anything here. The view just
    /// reads `poller.latest` and re-renders when it changes.
    ///
    /// Swift 6 strict concurrency: `.shared` is main-actor-isolated,
    /// so we can't use it as an inline default stored-property value.
    /// Explicit @MainActor init sidesteps the error.
    @ObservedObject private var poller: DashboardPoller
    @State private var selectedTab: DashboardTab = .performance

    /// Server-canonical Race-Now verdict. Re-fetched via CalcClient
    /// whenever the underlying `when` profile changes (i.e. on every
    /// dashboard poll that updates the When-engine state). The view
    /// renders `evaluation.verdict` + `evaluation.detail` verbatim —
    /// no local synthesis from peak/worst hour ranges. Same numbers
    /// as the web dashboard's ShouldIRaceNow chip.
    @State private var raceNowEvaluation: RaceNowEvaluation?
    @State private var raceNowAlternatives: [RaceNowAlternative] = []

    @MainActor
    init() {
        self.poller = .shared
    }

    private var dashboard: Dashboard? { poller.latest }
    private var recentSessions: [Dashboard.RecentSession] { poller.sessions }
    private var isLoadingInitialData: Bool { poller.latest == nil && poller.isPolling }

    var body: some View {
        ZStack {
            // No local ThemedBackgroundView — the signed-in root
            // (ContentView) owns it so the image extends behind the
            // sidebar too. The dashboard just sits on top.
            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 0) {
                    mainColumn
                        .frame(maxWidth: .infinity)

                    // Glass sidebar is its own floating panel now —
                    // drop the vertical hairline that used to live
                    // between it and the main column, and give the
                    // panel breathing room on all four sides so its
                    // rounded corners + shadow render cleanly.
                    SidebarTabs(
                        tracks: dashboard?.topTracks ?? [],
                        cars: dashboard?.topCars ?? [],
                        lookups: dashboard?.lookups
                    )
                    .frame(width: 320)
                    .padding(.top, 8)
                    .padding(.trailing, 12)
                    .padding(.bottom, 10)
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

            if isLoadingInitialData {
                ProgressView().controlSize(.large)
            }
        }
        // Refetch the canonical Race-Now verdict whenever the When
        // profile shifts — new poll, hour rollover, login change.
        // Keying on peakHourStart (a primitive Int) keeps the task id
        // hashable without requiring WhenProfile to conform to Hashable.
        .task(id: dashboard?.when?.peakHourStart) {
            await refreshRaceNow()
        }
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
                        NextRaceTabContent(
                            ideas: dashboard?.nextRaceIdeas ?? [],
                            lookups: dashboard?.lookups
                        )
                    case .previous:
                        PreviousRacesTabContent(sessions: recentSessions)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 30)
            }
        }
    }

    @ViewBuilder
    private var performanceContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            shouldYouRacePanel
            strengthsWatchOutPanel

            // Viz modules stack vertically at full main-column width —
            // each chart has room to breathe (the horizontal 3-up
            // layout squeezed them at typical window sizes).
            VStack(spacing: 14) {
                RaceCalendarHeatmap(sessions: recentSessions)
                RaceScheduleScatter(buckets: dashboard?.scatterBuckets ?? [])
                DriverDNARadar(dashboard: dashboard)
            }
        }
    }

    /// "Should You Race Right Now?" panel — verdict + detail rendered
    /// verbatim from the server's `/api/v1/calc/race-now` evaluation.
    ///
    /// We deliberately do NOT synthesize verdict from peak/worst hour
    /// ranges locally — that's what produced the old "Marginal" result
    /// when the canonical server verdict for the same moment was
    /// "risky" (different inputs: server uses incident rate + win rate
    /// + position data; the old local check only saw hour membership).
    /// Native and web now display identical strings + numbers because
    /// they share the same compute path.
    @ViewBuilder
    private var shouldYouRacePanel: some View {
        if let when = dashboard?.when {
            let panel = dashboard?.whenPanel
            let hour = Calendar.current.component(.hour, from: Date())
            let peakRange = when.peakHourStart..<(when.peakHourStart + when.windowSize)
            let worstRange = when.worstHourStart..<(when.worstHourStart + when.windowSize)
            let inPeak = peakRange.contains(hour)
            let inWorst = worstRange.contains(hour)

            let detail = ShouldYouRacePanel.Detail(
                peakWindow: panel?.strengths.map { "\($0.days), \($0.hours)" },
                peakDelta: panel?.strengths.flatMap { side in
                    side.avgIRatingDelta.map { formatDelta($0) }
                },
                worstWindow: panel?.watchOut.map { "\($0.days), \($0.hours)" },
                worstDelta: panel?.watchOut.flatMap { side in
                    side.avgIRatingDelta.map { formatDelta($0) }
                },
                nowDescription: nowAnnotation(hour: hour, inPeak: inPeak, inWorst: inWorst)
            )

            if let evaluation = raceNowEvaluation {
                ShouldYouRacePanel(
                    verdict: mapServerVerdict(evaluation.verdict),
                    title: titleForServerVerdict(evaluation.verdict),
                    reason: evaluation.detail,
                    detail: detail
                )
            } else {
                // Server fetch hasn't completed yet (or failed). Show a
                // neutral placeholder with the rich peak/worst context
                // already available from /api/v1/dashboard.
                ShouldYouRacePanel(
                    verdict: .unknown,
                    title: "Calculating…",
                    reason: "Loading current race-now verdict from server.",
                    detail: detail
                )
            }
        } else {
            ShouldYouRacePanel(
                verdict: .unknown,
                title: "Not enough data",
                reason: "Add a few more races to get a race-now advisory."
            )
        }
    }

    /// Server verdict vocabulary: `'good' | 'marginal' | 'risky' | 'insufficient'`.
    /// Native ShouldYouRacePanel.Verdict: `.good | .marginal | .bad | .unknown`.
    private func mapServerVerdict(_ verdict: String) -> ShouldYouRacePanel.Verdict {
        switch verdict {
        case "good":     return .good
        case "marginal": return .marginal
        case "risky":    return .bad
        default:         return .unknown   // "insufficient" or unrecognised
        }
    }

    /// Title strings keyed off the server verdict — kept here rather
    /// than driven by the server so we have control over native copy
    /// while the underlying decision remains canonical.
    private func titleForServerVerdict(_ verdict: String) -> String {
        switch verdict {
        case "good":     return "Go for it"
        case "marginal": return "Marginal"
        case "risky":    return "Risky window"
        default:         return "Not enough data"
        }
    }

    /// Refetches the canonical race-now verdict from web-api. Triggered
    /// by `.task(id:)` whenever the dashboard's `when` profile changes —
    /// new poll cycle, hour rollover (when peakHourStart shifts), or
    /// initial load. The server's verdict only changes on hour boundaries
    /// so polling every dashboard cycle is acceptable; per-tick polling
    /// would be wasteful.
    private func refreshRaceNow() async {
        guard let when = dashboard?.when else {
            await MainActor.run {
                raceNowEvaluation = nil
                raceNowAlternatives = []
            }
            return
        }
        do {
            // Bridge: dashboard.when (typed `Dashboard.WhenProfile`) and
            // calc API's profile (opaque `JSONValue`) are shape-compatible
            // — both come from the same server-side `computeWhenProfile`.
            // Round-trip through JSON to cross the typed↔opaque boundary.
            let encoded = try JSONEncoder().encode(when)
            let opaque = try JSONDecoder().decode(JSONValue.self, from: encoded)
            let response = try await CalcClient.shared.raceNow(profile: opaque)
            await MainActor.run {
                raceNowEvaluation = response.evaluation
                raceNowAlternatives = response.alternatives
            }
        } catch {
            Log.error("[CalcClient] race-now fetch failed: \(error)")
            await MainActor.run {
                raceNowEvaluation = nil
                raceNowAlternatives = []
            }
        }
    }

    /// "Currently 6:18 PM Thursday — inside your peak window." style
    /// annotation for the expanded ShouldYouRace detail.
    private func nowAnnotation(hour: Int, inPeak: Bool, inWorst: Bool) -> String {
        let df = DateFormatter()
        df.dateFormat = "h:mm a 'on' EEEE"
        let timeStr = df.string(from: Date())
        if inPeak  { return "Currently \(timeStr) — inside your peak window." }
        if inWorst { return "Currently \(timeStr) — inside your weakest window." }
        return "Currently \(timeStr) — outside both windows."
    }

    /// Strengths / Watch Out panel. Reads the server-pre-computed
    /// `whenPanel` view-model — the same object `@/lib/when-panel-view`
    /// builds for the web component. Zero Swift re-computation; the
    /// paragraph and bullets are verbatim what the web renders.
    @ViewBuilder
    private var strengthsWatchOutPanel: some View {
        let panel = dashboard?.whenPanel
        if let strengths = panel?.strengths, let watchOut = panel?.watchOut {
            StrengthsWatchOutPanel(
                strengths: .init(
                    label: "STRENGTHS",
                    tint: Palette.success,
                    window: "\(strengths.days)\n\(strengths.hours)",
                    footnote: strengths.avgIRatingDelta.map { formatDelta($0) },
                    summary: strengths.paragraph,
                    bullets: strengths.bullets.map(\.text)
                ),
                watchOut: .init(
                    label: "WATCH OUT",
                    tint: Palette.brand,
                    window: "\(watchOut.days)\n\(watchOut.hours)",
                    footnote: watchOut.avgIRatingDelta.map { formatDelta($0) },
                    summary: watchOut.paragraph,
                    bullets: watchOut.bullets.map(\.text)
                )
            )
        } else {
            StrengthsWatchOutPanel(
                strengths: .init(
                    label: "STRENGTHS", tint: Palette.success,
                    window: "Collecting data", footnote: nil,
                    summary: "Run 5+ sessions to see your strongest time windows.",
                    bullets: []
                ),
                watchOut: .init(
                    label: "WATCH OUT", tint: Palette.brand,
                    window: "Collecting data", footnote: nil,
                    summary: "Incident hotspots surface once more sessions are logged.",
                    bullets: []
                )
            )
        }
    }

    /// Format the iRating window-average delta the web shows under the
    /// window label ("avg +296 iR"). Matches the web's formatter.
    private func formatDelta(_ delta: Double) -> String {
        let sign = delta > 0 ? "+" : ""
        return "avg \(sign)\(Int(delta.rounded())) iR"
    }

    private func toolbarLink(label: String, icon: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 10, weight: .semibold))
            Text(label).font(.system(size: 11, weight: .medium))
        }
        .foregroundColor(Palette.textDim)
    }

}

#Preview {
    DashboardView()
        .environmentObject(AuthManager())
        .frame(width: 1400, height: 900)
}
