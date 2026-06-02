import SwiftUI

/// Typed route wrapper used to push a track-detail destination onto
/// `TracksView`'s NavigationStack. Boxing the track name in a struct
/// (instead of using a raw `String`) keeps the stack's
/// navigationDestination registry unambiguous as more drill-ins land.
struct TrackDetailRoute: Hashable {
    let trackName: String
}

/// Track detail page — drilled into when a `TrackMasteryCard` is
/// tapped. Mirrors the web's `/drive/track/[name]` page using only
/// data already on the dashboard payload:
///
///   - Track meta (display name / SVG / image) → `lookups.tracks`
///   - Mastery (score / tier / trend)         → `topTracks[]`
///   - Aggregate stats + recent sessions      → `previousRaces[]`
///     filtered by trackName
///
/// Items deferred to a follow-up server PR (need new endpoints):
/// per-track iRating chart, incident heatmap, and the server-baked
/// narrative summary the web shows.
struct TrackDetailView: View {
    let trackName: String

    @ObservedObject private var poller: DashboardPoller

    @MainActor
    init(trackName: String) {
        self.trackName = trackName
        self.poller = .shared
    }

    private var dashboard: Dashboard? { poller.latest }
    private var lookups: Dashboard.Lookups? { dashboard?.lookups }
    private var trackLookup: Dashboard.TrackLookup? { lookups?.track(for: trackName) }

    /// All Previous Races at this track. The dashboard's
    /// `previousRaces` array already carries everything we need
    /// (best lap, field size, position color, date label).
    private var trackSessions: [Dashboard.PreviousRaceCard] {
        let cards = dashboard?.previousRaces ?? []
        return cards.filter { card in
            let target = trackName.lowercased()
            let candidate = (card.session.trackName ?? "").lowercased()
            return candidate == target
        }
    }

    private var mastery: Dashboard.TrackMasteryEntry? {
        dashboard?.topTracks?.first { $0.trackName.caseInsensitiveCompare(trackName) == .orderedSame }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                hero
                statsRow
                    .padding(.horizontal, 24)
                if !carsUsed.isEmpty {
                    carsUsedSection
                        .padding(.horizontal, 24)
                }
                if !lapTimeSeries.isEmpty {
                    lapTimeChart
                        .padding(.horizontal, 24)
                }
                if !trackSessions.isEmpty {
                    sessionsList
                        .padding(.horizontal, 24)
                }
                Spacer(minLength: 30)
            }
        }
        .navigationTitle(trackLookup?.displayName ?? trackName)
    }

    // MARK: - Hero

    @ViewBuilder
    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            // Background photo (faint).
            Group {
                if let url = trackLookup?.imageUrl.flatMap(URL.init) {
                    TrackImage(url: url).opacity(0.30)
                } else {
                    Palette.bgElevated
                }
            }

            // Large centered SVG silhouette.
            if let svg = trackLookup?.svgPath {
                TrackSilhouette(svgPath: svg, stroke: tierColor.opacity(0.55), lineWidth: 1.2)
                    .padding(40)
                    .allowsHitTesting(false)
            }

            // Bottom gradient for legibility.
            LinearGradient(
                colors: [.clear, Color.black.opacity(0.6)],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)

            HStack(alignment: .bottom, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(trackLookup?.displayName ?? trackName)
                        .font(.system(size: 26, weight: .heavy))
                        .foregroundColor(Palette.textPrimary)
                        .lineLimit(2)
                    Text("\(trackSessions.count) race\(trackSessions.count == 1 ? "" : "s") here")
                        .font(.system(size: 12))
                        .foregroundColor(Palette.textDim)
                }
                Spacer(minLength: 8)
                if let mastery {
                    masteryBadge(mastery)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 30)
            .padding(.bottom, 22)
        }
        .frame(height: 240)
    }

    private func masteryBadge(_ mastery: Dashboard.TrackMasteryEntry) -> some View {
        HStack(spacing: 12) {
            MasteryProgressRing(score: mastery.masteryScore, color: tierColor)
                .scaleEffect(1.4)
                .frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 1) {
                Text(mastery.masteryTier.prefix(1).uppercased() + mastery.masteryTier.dropFirst())
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(tierColor)
                Text(trendLabel(mastery.trend))
                    .font(.system(size: 10))
                    .foregroundColor(Palette.textDim)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.black.opacity(0.55))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(tierColor.opacity(0.35), lineWidth: 1)
                )
        )
    }

    private var tierColor: Color {
        switch mastery?.masteryTier {
        case "diamond": return Color(hex: "#b9f2ff")
        case "gold":    return Color(hex: "#ffd700")
        case "silver":  return Color(hex: "#c0c0c0")
        case "bronze":  return Color(hex: "#cd7f32")
        default:        return Palette.textMuted
        }
    }

    private func trendLabel(_ trend: String) -> String {
        switch trend {
        case "improving": return "Improving"
        case "declining": return "Declining"
        case "new":       return "New"
        default:          return "Stable"
        }
    }

    // MARK: - Stats row

    /// Aggregated 6-up stats. Best/worst position, win/podium counts,
    /// clean-race count are all derived from `previousRaces` filtered
    /// by track — same numbers the web's `TrackDetailClient` shows
    /// in the hero stat panel.
    private var statsRow: some View {
        HStack(spacing: 0) {
            statCol("Races", value: "\(trackSessions.count)")
            divider
            statCol("Wins", value: "\(winCount)")
            divider
            statCol("Podiums", value: "\(podiumCount)")
            divider
            statCol("Clean", value: "\(cleanRaceCount)")
            divider
            statCol("Best", value: bestPosition.map { "P\($0)" } ?? "—")
            divider
            statCol("Avg Inc", value: String(format: "%.1f", avgIncidents))
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

    private var winCount: Int {
        trackSessions.filter { $0.session.finishPosition == 1 }.count
    }

    private var podiumCount: Int {
        trackSessions.filter {
            guard let p = $0.session.finishPosition else { return false }
            return p >= 1 && p <= 3
        }.count
    }

    private var cleanRaceCount: Int {
        trackSessions.filter { ($0.session.incidentCount ?? 0) == 0 }.count
    }

    private var bestPosition: Int? {
        trackSessions.compactMap { $0.session.finishPosition }
            .filter { $0 > 0 }
            .min()
    }

    private var avgIncidents: Double {
        guard !trackSessions.isEmpty else { return 0 }
        let total = trackSessions.reduce(0) { $0 + ($1.session.incidentCount ?? 0) }
        return Double(total) / Double(trackSessions.count)
    }

    // MARK: - Cars used

    /// Per-car session counts at this track. Keys are car models from
    /// the user's session metadata; brand visuals come from the
    /// dashboard `lookups.cars` bundle (same lookup the dashboard
    /// uses everywhere).
    private var carsUsed: [(carModel: String, count: Int, lookup: Dashboard.CarLookup?)] {
        var counts: [String: Int] = [:]
        for card in trackSessions {
            counts[card.session.carModel, default: 0] += 1
        }
        return counts
            .sorted { $0.value > $1.value }
            .map { (carModel: $0.key, count: $0.value, lookup: lookups?.car(for: $0.key)) }
    }

    private var carsUsedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "car.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Palette.textSecondary)
                Text("Cars Used")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Palette.textSecondary)
            }
            VStack(spacing: 6) {
                ForEach(Array(carsUsed.enumerated()), id: \.offset) { _, entry in
                    HStack(spacing: 10) {
                        if let lookup = entry.lookup, lookup.logoSvg != nil || lookup.logoPng != nil {
                            BrandLogo(lookup: lookup, height: 18)
                                .frame(width: 30, alignment: .leading)
                        } else {
                            Spacer().frame(width: 30)
                        }
                        Text(entry.carModel)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Palette.textSecondary)
                            .lineLimit(1)
                        Spacer(minLength: 6)
                        Text("\(entry.count) race\(entry.count == 1 ? "" : "s")")
                            .font(.system(size: 11))
                            .foregroundColor(Palette.textDim)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
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

    // MARK: - Lap-time chart

    /// Best-lap-time series across this track's races, oldest first.
    /// Pulled directly from `previousRaces[].session.bestLapTime` —
    /// already in seconds (decimal). Matches the web's
    /// `lapTimeHistory` data shape.
    private var lapTimeSeries: [(date: Date, time: Double)] {
        let isoFmt = ISO8601DateFormatter()
        isoFmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return trackSessions.compactMap { card -> (Date, Double)? in
            guard let lap = card.session.bestLapTime, lap > 0 else { return nil }
            let date = isoFmt.date(from: card.session.createdAt)
                ?? ISO8601DateFormatter().date(from: card.session.createdAt)
            guard let date else { return nil }
            return (date, lap)
        }
        .sorted { $0.0 < $1.0 }
    }

    @ViewBuilder
    private var lapTimeChart: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "stopwatch")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Palette.textSecondary)
                Text("Best Lap Times")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Palette.textSecondary)
                Spacer()
                if let best = lapTimeSeries.map(\.time).min() {
                    Text("Best: \(formatLap(best))")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Palette.brand)
                }
            }
            LapTimeSparkline(points: lapTimeSeries.map(\.time))
                .frame(height: 80)
        }
        .padding(14)
        .panel(padding: 0)
    }

    private func formatLap(_ seconds: Double) -> String {
        guard seconds > 0 else { return "—" }
        let m = Int(seconds) / 60
        let s = seconds - Double(m * 60)
        let pad = s < 10 ? "0" : ""
        return "\(m):\(pad)\(String(format: "%.3f", s))"
    }

    // MARK: - Sessions list

    private var sessionsList: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Palette.textSecondary)
                Text("Races at this Track")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Palette.textSecondary)
            }
            VStack(spacing: 0) {
                ForEach(Array(trackSessions.enumerated()), id: \.element.id) { idx, card in
                    PreviousRaceListRow(card: card, lookups: lookups)
                    if idx != trackSessions.count - 1 {
                        Divider().overlay(Palette.borderSubtle)
                    }
                }
            }
            .panel(padding: 0)
        }
    }
}

// MARK: - Lap-time sparkline

/// Compact sparkline of best lap times over time. Lower = better, so
/// the polyline trends DOWN when the user is improving. Pure SwiftUI
/// `Path` rendering — no Charts dependency.
struct LapTimeSparkline: View {
    let points: [Double]

    var body: some View {
        GeometryReader { geo in
            Canvas { ctx, size in
                guard points.count >= 2,
                      let minVal = points.min(),
                      let maxVal = points.max(),
                      maxVal > minVal else {
                    // Single-point or flat: render a flat brand line
                    // mid-height so the section doesn't read as broken.
                    var p = Path()
                    p.move(to: CGPoint(x: 0, y: size.height / 2))
                    p.addLine(to: CGPoint(x: size.width, y: size.height / 2))
                    ctx.stroke(p, with: .color(Palette.brand.opacity(0.6)), lineWidth: 1.5)
                    return
                }
                let range = maxVal - minVal
                let stepX = size.width / CGFloat(points.count - 1)

                // Filled area under the line.
                var fill = Path()
                fill.move(to: CGPoint(x: 0, y: size.height))
                for (i, v) in points.enumerated() {
                    let x = CGFloat(i) * stepX
                    let y = size.height - (CGFloat((v - minVal) / range)) * size.height
                    if i == 0 {
                        fill.addLine(to: CGPoint(x: x, y: y))
                    } else {
                        fill.addLine(to: CGPoint(x: x, y: y))
                    }
                }
                fill.addLine(to: CGPoint(x: size.width, y: size.height))
                fill.closeSubpath()
                ctx.fill(fill, with: .color(Palette.brand.opacity(0.10)))

                // Line.
                var line = Path()
                for (i, v) in points.enumerated() {
                    let x = CGFloat(i) * stepX
                    let y = size.height - (CGFloat((v - minVal) / range)) * size.height
                    if i == 0 { line.move(to: CGPoint(x: x, y: y)) }
                    else      { line.addLine(to: CGPoint(x: x, y: y)) }
                }
                ctx.stroke(line, with: .color(Palette.brand), lineWidth: 1.5)

                // Endpoint dots.
                for (i, v) in points.enumerated() {
                    let x = CGFloat(i) * stepX
                    let y = size.height - (CGFloat((v - minVal) / range)) * size.height
                    let dot = Path(ellipseIn: CGRect(x: x - 2, y: y - 2, width: 4, height: 4))
                    let isBest = (v == minVal)
                    ctx.fill(dot, with: .color(isBest ? Color(hex: "#43c772") : Palette.brand))
                }
            }
            _ = geo // silence unused warning
        }
    }
}
