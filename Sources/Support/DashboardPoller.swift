import Foundation
import Combine
import SwiftUI

/// Periodically polls `/api/v1/dashboard` + `/api/v1/sessions` while
/// the user is signed in, publishes the latest snapshot, and fires
/// desktop notifications when it sees new moments, new race results,
/// or an imminent upcoming race.
///
/// Why polling rather than push: the product surface doesn't have a
/// server→client push channel yet (no WebSocket, no APNS). Polling is
/// the shortest path to "the dashboard shows fresh data without the
/// user hitting a refresh button". Can be swapped for a WebSocket
/// subscription later without changing the consumer API — `latest`
/// + `sessions` are both `@Published`.
///
/// Tick cadence is 60s — aggressive enough to feel live, gentle
/// enough to not rack up the Vercel function budget. Each tick fires
/// the two endpoints concurrently and diffs results against the prior
/// snapshot to decide what (if anything) to notify about.
@MainActor
final class DashboardPoller: ObservableObject {
    static let shared = DashboardPoller()

    @Published private(set) var latest: Dashboard?
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var isPolling = false

    /// Convenience accessor — recent sessions now ship INSIDE the
    /// dashboard payload. Callers read `poller.sessions`; under the
    /// hood it's `latest?.recentSessions`. Kept as a computed
    /// property so existing view code doesn't have to change shape.
    var sessions: [Dashboard.RecentSession] {
        latest?.recentSessions ?? []
    }

    /// Server-baked Previous Races cards — pre-paired (race ↔ practice
    /// ↔ qualifying) and pre-formatted by
    /// `apps/web-api/src/calc/previous-races.ts`. The Previous Races
    /// tab renders these verbatim; no client-side pairing or
    /// view-model derivation. Empty array when missing or when the
    /// user hasn't raced yet.
    var previousRaces: [Dashboard.PreviousRaceCard] {
        latest?.previousRaces ?? []
    }

    /// Seconds between polls. Tunable here so future load tests can
    /// adjust without hunting through view code.
    static let pollInterval: TimeInterval = 60

    /// Look-ahead window for "upcoming race" notifications — if the
    /// top-scored Next-Race-Idea starts within this many minutes we
    /// surface it. 30 minutes is enough warning to log into iRacing
    /// but not so long that every medium-future race spams.
    private static let upcomingWindowMinutes: Int = 30

    private var pollTask: Task<Void, Never>?

    /// Known IDs from the previous snapshot — used to diff and find
    /// what's NEW this tick. Deliberately in-memory per process; the
    /// `NotificationCoordinator` also dedups via identifier.
    private var knownMomentIds: Set<String> = []
    private var knownSessionIds: Set<String> = []
    private var notifiedUpcomingStartsAt: Set<String> = []

    private init() {}

    /// Start the polling loop. Safe to call multiple times — existing
    /// task is cancelled first. Call from the signed-in root so it
    /// doesn't fire against a logged-out user.
    func start() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.tick()
                try? await Task.sleep(nanoseconds: UInt64(Self.pollInterval * 1_000_000_000))
            }
        }
    }

    /// Stop the polling loop. Called on sign-out. Resets known-id sets
    /// so a different user doesn't inherit the previous session's
    /// notification-dedup state.
    func stop() {
        pollTask?.cancel()
        pollTask = nil
        knownMomentIds.removeAll()
        knownSessionIds.removeAll()
        notifiedUpcomingStartsAt.removeAll()
    }

    /// Fetch + diff + notify. Called on each tick. Errors are logged
    /// but not surfaced — polling is a background concern, failures
    /// shouldn't interrupt the user.
    private func tick() async {
        isPolling = true
        defer { isPolling = false }

        // Single fetch — `dashboard.recentSessions` now covers what
        // used to need a separate `/api/v1/sessions` hit. Half the
        // round trips, guaranteed consistency between the dashboard
        // and the session-driven panels (Calendar + Previous Races).
        do {
            let newDashboard = try await APIClient.shared.dashboard()
            Log.info("[POLL] dashboard ok — recentSessions=\(newDashboard.recentSessions?.count ?? 0), scatterBuckets=\(newDashboard.scatterBuckets?.count ?? 0), topTracks=\(newDashboard.topTracks?.count ?? 0), lookupTracks=\(newDashboard.lookups?.tracks.count ?? 0)")
            await diffAndNotify(newDashboard: newDashboard)
            latest = newDashboard
        } catch {
            Log.error("[POLL] dashboard fetch failed: \(error)")
        }
        lastUpdated = Date()
    }

    // MARK: - Diff + notify

    private func diffAndNotify(newDashboard: Dashboard) async {
        let newSessions: [Dashboard.RecentSession] = newDashboard.recentSessions ?? []
        // First tick establishes the baseline without firing
        // notifications — otherwise we'd flood the user with every
        // historical moment/race as if they just happened.
        let isFirstTick = knownMomentIds.isEmpty && knownSessionIds.isEmpty

        // 1. New moments — the server returns `recentMoments` sorted
        //    newest-first; anything not in our known set is new.
        let currentMoments = newDashboard.recentMoments ?? []
        for moment in currentMoments {
            if knownMomentIds.contains(moment.id) { continue }
            if !isFirstTick {
                await NotificationCoordinator.shared.post(
                    category: .moment,
                    title: moment.title,
                    body: moment.description,
                    deduplicationKey: "moment:\(moment.id)"
                )
            }
            knownMomentIds.insert(moment.id)
        }

        // 2. New race results — sessions we haven't seen before.
        for session in newSessions {
            if knownSessionIds.contains(session.id) { continue }
            if !isFirstTick {
                let posText = session.finishPosition.map { "P\($0)" } ?? "result"
                await NotificationCoordinator.shared.post(
                    category: .result,
                    title: "Race result — \(posText)",
                    body: "\(session.seriesName) · \(session.trackName)",
                    deduplicationKey: "session:\(session.id)"
                )
            }
            knownSessionIds.insert(session.id)
        }

        // 3. Upcoming race window — if a nextRaceIdea starts within
        //    our window AND we haven't announced it yet. The server
        //    currently isn't decoded into the native Dashboard model
        //    (next-race ideas is a separate follow-up), so this is a
        //    placeholder: once `Dashboard.nextRaceIdeas` is populated,
        //    this block lights up automatically.
        //
        //    Intentionally left in place so the notification wiring
        //    is ready the moment the data is.
        _ = Self.upcomingWindowMinutes
    }
}
