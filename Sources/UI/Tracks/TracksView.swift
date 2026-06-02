import SwiftUI

/// Full Tracks destination — mirrors the web's `TrackMasteryPage.tsx`.
/// Hero band with title + stats, then a 2-column grid of `TrackCard`s
/// rendered straight from `dashboard.topTracks`.
///
/// Note on data: native currently consumes `dashboard.topTracks`
/// which the server caps at 10 entries (intended for the dashboard
/// sidebar). The full track list (web shows ALL tracks with mastery
/// scores) requires either bumping that cap or shipping a separate
/// `allTracks` field. Tracked as a follow-up; today's view shows up
/// to 10 — better than the placeholder it's replacing.
struct TracksView: View {
    @ObservedObject private var poller: DashboardPoller

    @MainActor
    init() { self.poller = .shared }

    private var dashboard: Dashboard? { poller.latest }
    private var tracks: [Dashboard.TrackMasteryEntry] { dashboard?.topTracks ?? [] }
    private var lookups: Dashboard.Lookups? { dashboard?.lookups }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    hero
                    if tracks.isEmpty {
                        emptyCard
                            .padding(.horizontal, 24)
                            .padding(.top, 16)
                    } else {
                        trackGrid
                            .padding(.horizontal, 24)
                            .padding(.top, 16)
                            .padding(.bottom, 30)
                    }
                }
            }
            .navigationDestination(for: TrackDetailRoute.self) { route in
                TrackDetailView(trackName: route.trackName)
            }
        }
    }

    // MARK: - Hero

    /// Hero band — title + tagline + stats. A faint full-bleed track
    /// silhouette sits at the bottom-right when at least one track
    /// is available, just like the web's hero treatment.
    private var hero: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Track Mastery")
                    .font(.system(size: 30, weight: .heavy))
                    .foregroundColor(Palette.textPrimary)
                Text("Master the circuits. See your progression at every track.")
                    .font(.system(size: 13))
                    .foregroundColor(Palette.textDim)
                    .frame(maxWidth: 420, alignment: .leading)

                HStack(spacing: 28) {
                    statColumn(value: "\(dashboard?.stats.uniqueTracks ?? 0)", label: "Tracks")
                    statColumn(value: "\(dashboard?.stats.totalRaces ?? 0)", label: "Sessions")
                }
                .padding(.top, 14)
            }
            .padding(.horizontal, 24)
            .padding(.top, 30)
            .padding(.bottom, 28)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.bgPanel.opacity(0.5))

            // Decorative SVG silhouette — picks the first track that
            // has an svgPath available. Matches the web's "hero
            // randomly picks a track" effect; deterministic here so
            // re-renders are stable.
            if let svg = heroSvgPath {
                TrackSilhouette(svgPath: svg, stroke: Palette.brand.opacity(0.25), lineWidth: 1.4)
                    .frame(width: 320, height: 320)
                    .padding(.trailing, 30)
                    .padding(.bottom, 8)
                    .opacity(0.55)
                    .allowsHitTesting(false)
            }
        }
    }

    private var heroSvgPath: String? {
        guard let lookups else { return nil }
        // Pick the first lookup entry that has an svgPath. Stable
        // across renders within a single poller snapshot.
        return lookups.tracks.first(where: { $0.svgPath != nil })?.svgPath
    }

    private func statColumn(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 26, weight: .black))
                .monospacedDigit()
                .foregroundColor(Palette.textPrimary)
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.6)
                .foregroundColor(Palette.textMuted)
        }
    }

    // MARK: - Grid

    private var trackGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 14),
                GridItem(.flexible(), spacing: 14),
            ],
            alignment: .leading,
            spacing: 14
        ) {
            ForEach(tracks) { track in
                TrackMasteryCard(
                    track: track,
                    lookup: lookups?.track(for: track.trackName)
                )
            }
        }
    }

    // MARK: - Empty card

    private var emptyCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "mappin.circle")
                .font(.system(size: 32))
                .foregroundColor(Palette.brand.opacity(0.6))
            Text("Hit the track and your mastery profile will build automatically")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Palette.textPrimary)
                .multilineTextAlignment(.center)
            Text("Race at any circuit and you'll see your mastery score climb.")
                .font(.system(size: 12))
                .foregroundColor(Palette.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 50)
        .panel()
    }
}

// MARK: - Track card

/// Single track card — large SVG silhouette as the visual hero,
/// mastery progress ring + track name + tier badge overlaid at the
/// bottom of the visual, then a footer row with sessions / avg pos /
/// incidents-per-race + trend + "last raced" relative time.
struct TrackMasteryCard: View {
    let track: Dashboard.TrackMasteryEntry
    let lookup: Dashboard.TrackLookup?

    private var displayName: String {
        lookup?.displayName ?? track.trackName
    }

    var body: some View {
        // Whole card is a NavigationLink — tap anywhere to drill into
        // the per-track detail page. `.buttonStyle(.plain)` +
        // `.contentShape(Rectangle())` keep the visual identical and
        // make the entire card surface hit-testable.
        NavigationLink(value: TrackDetailRoute(trackName: track.trackName)) {
            VStack(alignment: .leading, spacing: 0) {
                visualHeader
                footer
            }
            .liquidGlassBackground(cornerRadius: 12)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Palette.borderSubtle, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Visual header

    private var visualHeader: some View {
        ZStack(alignment: .bottomLeading) {
            // Background photo (faint) — track image when available.
            Group {
                if let url = lookup?.imageUrl.flatMap(URL.init) {
                    TrackImage(url: url).opacity(0.18)
                } else {
                    Palette.bgElevated
                }
            }

            // Track silhouette — 200% size, slightly blurred, centered
            // — the dominant visual element matching the web's
            // overflow-cropped large-SVG treatment.
            if let svg = lookup?.svgPath {
                TrackSilhouette(svgPath: svg, stroke: tierColor.opacity(0.55), lineWidth: 1.0)
                    .scaleEffect(1.6)
                    .opacity(0.45)
                    .padding(.horizontal, -20)
                    .padding(.vertical, -8)
                    .allowsHitTesting(false)
            }

            // Bottom gradient for legibility of the overlaid name +
            // tier chip.
            LinearGradient(
                colors: [.clear, Color.black.opacity(0.55)],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)

            // Bottom row: mastery score ring + track name + tier chip
            HStack(alignment: .bottom, spacing: 10) {
                MasteryProgressRing(score: track.masteryScore, color: tierColor)
                Text(displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Palette.textPrimary)
                    .lineLimit(2)
                Spacer(minLength: 6)
                tierChip
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 10)
        }
        .frame(height: 160)
    }

    private var tierChip: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(tierColor)
                .frame(width: 6, height: 6)
            Text(track.masteryTier.prefix(1).uppercased() + track.masteryTier.dropFirst())
                .font(.system(size: 10, weight: .semibold))
        }
        .foregroundColor(tierColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(Color.black.opacity(0.55))
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }

    private var tierColor: Color {
        // Hex values match the web's TIER_COLORS map exactly so the
        // tier accent reads identically across platforms.
        switch track.masteryTier {
        case "diamond": return Color(hex: "#b9f2ff")
        case "gold":    return Color(hex: "#ffd700")
        case "silver":  return Color(hex: "#c0c0c0")
        case "bronze":  return Color(hex: "#cd7f32")
        default:        return Palette.textMuted
        }
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 18) {
                stat("Sessions", "\(track.totalSessions)")
                stat("Avg Pos", track.avgPosition.map { "P\(String(format: "%.1f", $0))" } ?? "—")
                stat("Inc/Race", String(format: "%.1f", track.avgIncidents))
            }

            Divider().overlay(Palette.borderSubtle)

            HStack {
                trendChip
                Spacer()
                Text(relativeTime(from: track.lastRaced))
                    .font(.system(size: 10))
                    .foregroundColor(Palette.textMuted)
            }
        }
        .padding(12)
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(Palette.textMuted)
            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .monospacedDigit()
                .foregroundColor(Palette.textSecondary)
        }
    }

    private var trendChip: some View {
        HStack(spacing: 4) {
            Image(systemName: trendIcon)
                .font(.system(size: 9, weight: .bold))
            Text(trendLabel)
                .font(.system(size: 10))
        }
        .foregroundColor(Palette.textDim)
    }

    private var trendIcon: String {
        switch track.trend {
        case "improving": return "arrow.up.right"
        case "declining": return "arrow.down.right"
        case "new":       return "circle.fill"
        default:          return "arrow.right"
        }
    }

    private var trendLabel: String {
        switch track.trend {
        case "improving": return "Improving"
        case "declining": return "Declining"
        case "new":       return "New"
        default:          return "Stable"
        }
    }

    /// "now / 12m / 3h / 4d / 2w" — same buckets as the web's
    /// `formatRelativeTime`. Server-baking this is on the follow-up
    /// list along with the rest of the Tracks viewModel.
    private func relativeTime(from iso: String) -> String {
        let isoFmt = ISO8601DateFormatter()
        isoFmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = isoFmt.date(from: iso) ?? ISO8601DateFormatter().date(from: iso)
        guard let date else { return iso }
        let diff = Date().timeIntervalSince(date)
        let s = Int(diff)
        if s < 60   { return "now" }
        let m = s / 60
        if m < 60   { return "\(m)m ago" }
        let h = m / 60
        if h < 24   { return "\(h)h ago" }
        let d = h / 24
        if d < 7    { return "\(d)d ago" }
        return "\(d / 7)w ago"
    }
}

// MARK: - Mastery progress ring

/// 32×32 circular progress ring with the score at the center.
/// SwiftUI Canvas — same look as the web's `MasteryProgressRing`
/// but drawn natively rather than as an SVG.
struct MasteryProgressRing: View {
    let score: Double
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(Palette.borderSubtle, lineWidth: 3)
                .frame(width: 32, height: 32)
            Circle()
                .trim(from: 0, to: CGFloat(min(max(score, 0), 100) / 100.0))
                .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 32, height: 32)
            Text("\(Int(score.rounded()))")
                .font(.system(size: 10, weight: .bold))
                .monospacedDigit()
                .foregroundColor(Palette.textSecondary)
        }
    }
}
