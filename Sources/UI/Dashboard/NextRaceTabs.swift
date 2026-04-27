import SwiftUI

// MARK: - Next Race tab

/// Ranked list of `NextRaceIdea` suggestions pulled from
/// `dashboard.nextRaceIdeas`. Server sorts by match score descending
/// so we just iterate in order.
struct NextRaceTabContent: View {
    let ideas: [Dashboard.NextRaceIdeaEntry]
    let lookups: Dashboard.Lookups?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if ideas.isEmpty {
                emptyState
            } else {
                ForEach(ideas) { idea in
                    NextRaceCard(
                        idea: idea,
                        trackLookup: lookups?.track(for: idea.trackName),
                        carLookups: idea.carClassNames.compactMap { lookups?.car(for: $0) }
                    )
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "flag.slash")
                .font(.system(size: 28))
                .foregroundColor(Palette.textMuted)
            Text("No race suggestions yet")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Palette.textSecondary)
            Text("Run a few more sessions — the Next Race engine needs 3+ races to compute suggestions.")
                .font(.system(size: 11))
                .foregroundColor(Palette.textDim)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: 420)
        .panel()
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

/// Hero-style Next Race card. Mirrors the web's `HeroRaceCard` in
/// `NextRaceIdeas.tsx`: track photo background + track silhouette
/// overlay + time/score chips + brand chips + license/official/
/// fixed/duration tags + strategy pill + commentary. Uses the
/// server-provided lookup bundle for all imagery — no SF Symbols.
struct NextRaceCard: View {
    let idea: Dashboard.NextRaceIdeaEntry
    let trackLookup: Dashboard.TrackLookup?
    let carLookups: [Dashboard.CarLookup]

    /// Score-tiered accent color. Prefers the server-baked
    /// `viewModel.scoreColorHex` so all clients render the same hex
    /// at the same score. Falls back to the local 4-tier threshold
    /// only if the server response predates the view-model rollout
    /// (prodrive-server PR #31).
    private var scoreTint: Color {
        if let hex = idea.viewModel?.scoreColorHex {
            return Color(hex: hex)
        }
        switch idea.score {
        case 80...:  return Palette.success                      // green
        case 60...:  return Color(hex: "#c7d93a")                // lime
        case 40...:  return Color(hex: "#ffcf4a")                // amber
        default:     return Color(hex: "#ff8c42")                // orange
        }
    }

    private var startsDate: Date? {
        ISO8601DateFormatter().date(from: idea.startsAtUtc)
    }

    /// Human-readable countdown. Prefers the server-baked
    /// `viewModel.startsInLabel` so web and native render the same
    /// copy verbatim ("in 2 hr 15 min" / "Starting now" / "Friday at
    /// 7:00 PM"). Falls back to RelativeDateTimeFormatter only when
    /// the server response predates the view-model rollout.
    ///
    /// Note: the server-baked label is computed at server-render
    /// time. If the user holds the dashboard open for many minutes
    /// the countdown will go stale. Acceptable for an initial
    /// render; refresh-on-poll updates it.
    private var startsInHumanReadable: String {
        if let label = idea.viewModel?.startsInLabel {
            return label
        }
        guard let date = startsDate else { return idea.startsAtUtc }
        let interval = date.timeIntervalSinceNow
        if interval < 0 { return "Starting now" }
        let fmt = RelativeDateTimeFormatter()
        fmt.unitsStyle = .full
        fmt.dateTimeStyle = .named
        if interval < 12 * 3600 {
            return fmt.localizedString(for: date, relativeTo: Date())
        }
        let df = DateFormatter()
        df.dateFormat = interval < 7 * 86400 ? "EEEE 'at' h:mm a" : "EEE MMM d 'at' h:mm a"
        return df.string(from: date)
    }

    /// Race-duration chip copy. Prefers the server-baked
    /// `viewModel.durationLabel` so web and native agree on
    /// formatting (e.g. "1 hr 30 min" vs "90 min"). Falls back to
    /// the local "{N} laps / {N} min" formatter when missing.
    private var durationLabel: String? {
        if let label = idea.viewModel?.durationLabel { return label }
        if let laps = idea.raceLapLimit, laps > 0 { return "\(laps) laps" }
        if let mins = idea.raceTimeLimit, mins > 0 { return "\(mins) min" }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            heroHeader
            bodySection
        }
        .liquidGlassBackground(cornerRadius: 12)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Palette.borderSubtle, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Header (image + silhouette + chips)

    private var heroHeader: some View {
        ZStack(alignment: .top) {
            // Base photo — track if present, car as fallback
            Group {
                if let url = trackLookup?.imageUrl.flatMap(URL.init) {
                    TrackImage(url: url).opacity(0.4)
                } else if let url = carLookups.first?.imageUrl.flatMap(URL.init) {
                    TrackImage(url: url).opacity(0.3)
                } else {
                    Palette.bgElevated
                }
            }

            // Track silhouette overlay (centered)
            if let svg = trackLookup?.svgPath {
                TrackSilhouette(svgPath: svg, stroke: Color.white.opacity(0.55), lineWidth: 1.4)
                    .padding(24)
            }

            // Bottom gradient for chip legibility
            LinearGradient(
                colors: [.clear, Color.black.opacity(0.55)],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)

            // Chips: time (TL), score (TR), brands (BL)
            VStack {
                HStack(alignment: .top) {
                    timeChip
                    Spacer()
                    scoreChip
                }
                Spacer()
                HStack(spacing: 6) {
                    ForEach(Array(carLookups.prefix(4).enumerated()), id: \.offset) { _, c in
                        BrandLogo(lookup: c, height: 20)
                            .padding(4)
                            .background(Capsule().fill(Color.black.opacity(0.5)))
                    }
                    Spacer()
                }
            }
            .padding(10)
        }
        .frame(height: 140)
    }

    private var timeChip: some View {
        HStack(spacing: 6) {
            Image(systemName: "clock")
                .font(.system(size: 10, weight: .bold))
            Text(startsInHumanReadable)
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundColor(Color.black.opacity(0.88))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(scoreTint))
    }

    private var scoreChip: some View {
        VStack(spacing: -2) {
            Text("\(Int(idea.score))")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(Palette.textPrimary)
            Text("MATCH")
                .font(.system(size: 8, weight: .bold))
                .tracking(0.8)
                .foregroundColor(Palette.textDim)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(Color.black.opacity(0.55)))
    }

    // MARK: - Body section

    private var bodySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Track + series
            HStack(alignment: .center, spacing: 8) {
                if let logoSvg = trackLookup?.logoSvg,
                   let image = SVGRenderer.rasterize(logoSvg, maxDimension: 40) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(trackLookup?.displayName ?? idea.trackName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Palette.textPrimary)
                    Text(idea.seriesName)
                        .font(.system(size: 11))
                        .foregroundColor(Palette.textDim)
                        .lineLimit(1)
                }
            }

            // Tags row
            HStack(spacing: 6) {
                tag(idea.license, filled: true, tint: licenseTint)
                if idea.official { tag("Official", filled: false) }
                if idea.fixed    { tag("Fixed", filled: false) }
                if let duration = durationLabel {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 8))
                        Text(duration)
                    }
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Palette.textSecondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().strokeBorder(Palette.borderSubtle, lineWidth: 1))
                }
                Spacer()
            }

            // Strategy + commentary
            HStack(alignment: .top, spacing: 8) {
                Text(idea.strategy.capitalized)
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.8)
                    .foregroundColor(Palette.textPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(scoreTint.opacity(0.28)))
                    .fixedSize()
                if !idea.commentary.isEmpty {
                    Text(idea.commentary)
                        .font(.system(size: 11))
                        .foregroundColor(Palette.textDim)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(14)
    }

    private func tag(_ label: String, filled: Bool, tint: Color = Palette.textSecondary) -> some View {
        Text(label)
            .font(.system(size: 10, weight: .bold))
            .tracking(0.6)
            .foregroundColor(filled ? .black : Palette.textSecondary)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                Group {
                    if filled {
                        Capsule().fill(tint)
                    } else {
                        Capsule().strokeBorder(Palette.borderSubtle, lineWidth: 1)
                    }
                }
            )
    }

    private var licenseTint: Color {
        switch idea.license.uppercased() {
        case "A": return Color(hex: "#7cdff0")
        case "B": return Color(hex: "#6fcf69")
        case "C": return Color(hex: "#ffcf4a")
        case "D": return Color(hex: "#ff8c42")
        default:  return Palette.brand
        }
    }
}

// MARK: - Previous Races tab

/// Chronological race history — a row per completed session, sourced
/// from `DashboardPoller.sessions` which the poller keeps fresh.
struct PreviousRacesTabContent: View {
    let sessions: [Dashboard.RecentSession]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if sessions.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 28))
                        .foregroundColor(Palette.textMuted)
                    Text("No completed races yet")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Palette.textSecondary)
                    Text("Race results will appear here once sessions are imported.")
                        .font(.system(size: 11))
                        .foregroundColor(Palette.textDim)
                }
                .frame(maxWidth: 420)
                .panel()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(sessions.enumerated()), id: \.element.id) { idx, session in
                        PreviousRaceRow(session: session)
                        if idx != sessions.count - 1 {
                            Divider().overlay(Palette.borderSubtle)
                        }
                    }
                }
                .panel(padding: 0)
            }
        }
    }
}

struct PreviousRaceRow: View {
    let session: Dashboard.RecentSession

    private var positionColor: Color {
        guard let pos = session.finishPosition else { return Palette.textDim }
        switch pos {
        case 1:     return Color(hex: "#ffcf4a")   // gold
        case 2...3: return Color(hex: "#d0d0dc")   // silver/podium
        case 4...10: return Palette.textPrimary
        default:    return Palette.textDim
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(spacing: 0) {
                Text(session.finishPosition.map { "P\($0)" } ?? "—")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(positionColor)
            }
            .frame(width: 48)

            VStack(alignment: .leading, spacing: 3) {
                Text(session.seriesName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Palette.textPrimary)
                    .lineLimit(1)
                Text(session.trackName)
                    .font(.system(size: 11))
                    .foregroundColor(Palette.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(session.startTime.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 10))
                    .foregroundColor(Palette.textDim)
                if let laps = session.lapsCompleted {
                    Text("\(laps) laps")
                        .font(.system(size: 10))
                        .foregroundColor(Palette.textMuted)
                }
            }
        }
        .padding(14)
    }
}
