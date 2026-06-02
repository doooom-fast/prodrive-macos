import SwiftUI

/// Typed route wrapper used as the `Hashable` value pushed onto a
/// `NavigationStack` when drilling into a race. Boxing the session
/// id in a struct (instead of using a bare `String`) keeps the
/// stack's navigationDestination registry unambiguous as more
/// drill-in destinations are added later (track/car/etc.).
struct SessionDetailRoute: Hashable {
    let sessionId: String
}

/// Rich race detail page — drilled into when a Previous Races card
/// is tapped. Mirrors the web's `/drive/race/[id]` layout (hero with
/// track image + SVG silhouette + position badge + brand chip,
/// performance row with iR/SR deltas, stats row with best lap +
/// completed laps + incidents, lap-time table when telemetry is
/// available).
///
/// Data source is `APIClient.session(id:)` which returns a
/// `SessionDetail`. Track / car visuals come from the dashboard
/// poller's `lookups` bundle so the same brand color + track SVG
/// the Previous Races card showed render here too.
struct SessionDetailView: View {
    let sessionId: String

    @State private var session: SessionDetail?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @ObservedObject private var poller: DashboardPoller

    @MainActor
    init(sessionId: String) {
        self.sessionId = sessionId
        self.poller = .shared
    }

    private var lookups: Dashboard.Lookups? { poller.latest?.lookups }
    private var trackLookup: Dashboard.TrackLookup? { lookups?.track(for: session?.trackName) }
    private var carLookup: Dashboard.CarLookup? { lookups?.car(for: session?.carName) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if isLoading && session == nil {
                    ProgressView().controlSize(.large)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 80)
                } else if let session {
                    hero(session: session)
                    performanceRow(session: session)
                        .padding(.horizontal, 24)
                    statsRow(session: session)
                        .padding(.horizontal, 24)
                    if let laps = session.laps, !laps.isEmpty {
                        lapsTable(laps: laps)
                            .padding(.horizontal, 24)
                    }
                    Spacer(minLength: 30)
                } else if let error = errorMessage {
                    errorState(message: error)
                        .padding(.top, 60)
                }
            }
        }
        .background(Color.clear)
        .navigationTitle("Race")
        .task { await loadSession() }
    }

    // MARK: - Hero

    @ViewBuilder
    private func hero(session: SessionDetail) -> some View {
        let pos = session.finishPosition
        let isDNF = pos == nil || pos == 0

        ZStack(alignment: .bottomLeading) {
            // Layer 1 — track or car photo (faint).
            Group {
                if let url = trackLookup?.imageUrl.flatMap(URL.init) {
                    TrackImage(url: url).opacity(0.30)
                } else if let url = carLookup?.imageUrl.flatMap(URL.init) {
                    TrackImage(url: url).opacity(0.22)
                } else {
                    Palette.bgElevated
                }
            }

            // Layer 2 — large track silhouette centered.
            if let svg = trackLookup?.svgPath {
                TrackSilhouette(svgPath: svg, stroke: Palette.brand.opacity(0.45), lineWidth: 1.4)
                    .padding(40)
                    .allowsHitTesting(false)
            }

            // Layer 3 — bottom gradient for chip legibility.
            LinearGradient(
                colors: [.clear, Color.black.opacity(0.6)],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)

            // Layer 4 — content (top-left brand chip, bottom-left
            // hero text + position badge).
            VStack(alignment: .leading) {
                HStack(alignment: .top) {
                    if let car = carLookup, car.logoSvg != nil || car.logoPng != nil {
                        brandChip(car: car)
                    }
                    Spacer()
                }

                Spacer(minLength: 0)

                HStack(alignment: .bottom, spacing: 18) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(trackLookup?.displayName ?? session.trackName)
                            .font(.system(size: 22, weight: .heavy))
                            .foregroundColor(Palette.textPrimary)
                            .lineLimit(2)
                        Text(session.seriesName)
                            .font(.system(size: 13))
                            .foregroundColor(Palette.textSecondary)
                            .lineLimit(1)
                        HStack(spacing: 8) {
                            Text(session.startTime.formatted(date: .abbreviated, time: .shortened))
                                .font(.system(size: 11))
                                .foregroundColor(Palette.textDim)
                            Text("·")
                                .font(.system(size: 11))
                                .foregroundColor(Palette.textDim)
                            Text(session.carName)
                                .font(.system(size: 11))
                                .foregroundColor(Palette.textDim)
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 8)
                    positionBadge(position: pos, isDNF: isDNF)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 30)
            .padding(.bottom, 22)
        }
        .frame(height: 240)
    }

    private func positionBadge(position: Int?, isDNF: Bool) -> some View {
        let color = positionColor(for: position, isDNF: isDNF)
        return Group {
            if isDNF {
                Text("DNF")
                    .font(.system(size: 38, weight: .black))
                    .foregroundColor(color)
            } else if let position {
                HStack(alignment: .lastTextBaseline, spacing: 1) {
                    Text("P")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(color.opacity(0.7))
                    Text("\(position)")
                        .font(.system(size: 56, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(color)
                }
            }
        }
    }

    private func brandChip(car: Dashboard.CarLookup) -> some View {
        let tint = car.color.flatMap { Color(hex: $0) }
        return BrandLogo(lookup: car, height: 28)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill((tint ?? Color.black.opacity(0.55)).opacity(tint == nil ? 1 : 0.33))
                    .overlay(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .strokeBorder((tint ?? Palette.borderSubtle).opacity(0.6), lineWidth: 1)
                    )
            )
    }

    private func positionColor(for pos: Int?, isDNF: Bool) -> Color {
        if isDNF { return Color(hex: "#E46767") }
        guard let pos else { return Palette.textDim }
        switch pos {
        case 1:        return Color(hex: "#F5CA47")
        case 2:        return Color(hex: "#C7C7C7")
        case 3:        return Color(hex: "#DA944E")
        case 4...10:   return Color(hex: "#54D483")
        default:       return Palette.textDim
        }
    }

    // MARK: - Performance row (iR / SR delta)

    @ViewBuilder
    private func performanceRow(session: SessionDetail) -> some View {
        if session.iRatingPre != nil || session.srPre != nil {
            HStack(spacing: 14) {
                if let pre = session.iRatingPre, let post = session.iRatingPost {
                    deltaCard(label: "iRating", before: "\(pre)", after: "\(post)", delta: post - pre)
                }
                if let pre = session.srPre, let post = session.srPost {
                    deltaCard(
                        label: "SR",
                        before: String(format: "%.2f", pre),
                        after: String(format: "%.2f", post),
                        delta: nil,
                        srDelta: post - pre
                    )
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func deltaCard(label: String, before: String, after: String, delta: Int? = nil, srDelta: Double? = nil) -> some View {
        let isPositive: Bool = {
            if let delta { return delta > 0 }
            if let srDelta { return srDelta > 0 }
            return false
        }()
        let isNegative: Bool = {
            if let delta { return delta < 0 }
            if let srDelta { return srDelta < 0 }
            return false
        }()
        let deltaColor: Color = isPositive ? Color(hex: "#43c772")
            : isNegative ? Color(hex: "#e35353") : Palette.textMuted
        let deltaText: String = {
            if let delta { return delta > 0 ? "+\(delta)" : "\(delta)" }
            if let srDelta {
                let sign = srDelta > 0 ? "+" : ""
                return "\(sign)\(String(format: "%.2f", srDelta))"
            }
            return ""
        }()

        return VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.4)
                .foregroundColor(Palette.textMuted)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(after)
                    .font(.system(size: 22, weight: .bold))
                    .monospacedDigit()
                    .foregroundColor(Palette.textPrimary)
                if !deltaText.isEmpty {
                    Text(deltaText)
                        .font(.system(size: 12, weight: .semibold))
                        .monospacedDigit()
                        .foregroundColor(deltaColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(deltaColor.opacity(0.14)))
                }
            }
            Text("from \(before)")
                .font(.system(size: 10))
                .foregroundColor(Palette.textDim)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .panel(padding: 0)
    }

    // MARK: - Stats row

    @ViewBuilder
    private func statsRow(session: SessionDetail) -> some View {
        HStack(spacing: 0) {
            statCol("Best Lap", value: formatLap(session.bestLapTime))
            divider
            statCol("Avg Lap", value: formatLap(session.avgLapTime))
            divider
            statCol("Laps", value: session.lapsCompleted.map { "\($0)" } ?? "—")
            divider
            statCol("Led", value: session.lapsLed.map { "\($0)" } ?? "—")
            divider
            statCol("Incidents", value: session.incidents.map { "\($0)" } ?? "—")
            divider
            statCol("Started", value: session.startPosition.map { "P\($0)" } ?? "—")
        }
        .padding(14)
        .panel(padding: 0)
    }

    private func statCol(_ label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.0)
                .foregroundColor(Palette.textMuted)
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .monospacedDigit()
                .foregroundColor(Palette.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Rectangle()
            .fill(Palette.borderSubtle)
            .frame(width: 1, height: 32)
    }

    // MARK: - Laps table

    @ViewBuilder
    private func lapsTable(laps: [Lap]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "clock")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Palette.textSecondary)
                Text("Lap Times")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Palette.textSecondary)
            }
            .padding(.bottom, 4)

            // Compact 2-column grid for the laps. Each row shows the
            // lap number, lap time, and an incident dot when set.
            // Keeps the table dense without becoming a wall of text.
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 14),
                    GridItem(.flexible(), spacing: 14),
                ],
                alignment: .leading,
                spacing: 4
            ) {
                ForEach(laps) { lap in
                    HStack(spacing: 8) {
                        Text("Lap \(lap.lapNumber)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Palette.textMuted)
                            .frame(width: 56, alignment: .leading)
                        Text(formatLap(lap.time))
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(lap.isIncident ? Color(hex: "#e35353") : Palette.textSecondary)
                        Spacer(minLength: 0)
                        if lap.isIncident {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 10))
                                .foregroundColor(Color(hex: "#e35353"))
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.white.opacity(0.04))
                    )
                }
            }
        }
        .padding(14)
        .panel(padding: 0)
    }

    // MARK: - Error state

    private func errorState(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 28))
                .foregroundColor(Color(hex: "#e35353"))
            Text("Couldn't load this race")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Palette.textPrimary)
            Text(message)
                .font(.system(size: 11))
                .foregroundColor(Palette.textDim)
                .multilineTextAlignment(.center)
            Button("Retry") {
                Task { await loadSession() }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 50)
        .padding(.horizontal, 24)
    }

    // MARK: - Helpers

    /// Format a lap time. `SessionDetail.bestLapTime` / `avgLapTime`
    /// are stored as integer **milliseconds** on the wire (matches
    /// iRacing's source format); convert to seconds before printing.
    /// Returns "—" for nil / non-positive values so the cell never
    /// shows "0:00.000".
    private func formatLap(_ ms: Int?) -> String {
        guard let ms, ms > 0 else { return "—" }
        let totalSec = Double(ms) / 1000.0
        let m = Int(totalSec) / 60
        let s = totalSec - Double(m * 60)
        let pad = s < 10 ? "0" : ""
        return "\(m):\(pad)\(String(format: "%.3f", s))"
    }

    private func loadSession() async {
        isLoading = true
        errorMessage = nil
        do {
            session = try await APIClient.shared.session(id: sessionId)
        } catch {
            errorMessage = error.localizedDescription
            Log.error("[RaceDetail] failed to load session \(sessionId): \(error)")
        }
        isLoading = false
    }
}

#Preview {
    SessionDetailView(sessionId: "preview-session")
}
