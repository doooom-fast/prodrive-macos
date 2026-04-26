#if DEBUG
import Foundation

extension CalcClient {
    /// Calls every calc endpoint with the smallest valid input and logs
    /// success / failure. Use this in DEBUG builds to verify the
    /// CalcClient is wired up end-to-end (network, auth, decoders)
    /// without committing to specific UX yet.
    ///
    /// Safe to fire-and-forget on app launch:
    ///
    ///     #if DEBUG
    ///     Task { await CalcClient.runDebugSmokeTest() }
    ///     #endif
    ///
    /// race-summary and next-race-ideas require non-empty inputs to
    /// produce useful responses; they're skipped in the smoke test.
    /// race-summary in particular validates a session payload and
    /// returns 400 on empty bodies.
    nonisolated public static func runDebugSmokeTest() async {
        let client = CalcClient.shared
        print("[CalcClient] smoke test starting")

        await runOne("dna")      { _ = try await client.driverDna(sessions: [], ratings: []) }
        await runOne("mastery")  { _ = try await client.mastery(sessions: []) }
        await runOne("moments")  { _ = try await client.moments(sessions: [], ratings: []) }
        await runOne("scatter")  { _ = try await client.scatter(sessions: []) }
        await runOne("when")     { _ = try await client.whenEngine(sessions: [], ratings: []) }
        await runOne("race-now") { _ = try await client.raceNow() }

        print("[CalcClient] smoke test done (race-summary + next-race-ideas skipped — require non-empty inputs)")
    }

    private static func runOne(_ name: String, _ block: () async throws -> Void) async {
        do {
            try await block()
            print("[CalcClient] ✓ \(name)")
        } catch {
            print("[CalcClient] ✗ \(name): \(error.localizedDescription)")
        }
    }
}
#endif
