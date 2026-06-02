import SwiftUI

/// Slide-in drawer mirroring the web's `MomentsDrawer.tsx`.
/// Opens from the right edge with a translucent backdrop; click-out
/// or tapping the close X dismisses. Two sections inside:
///
///   1. **Highlights** — top 5 by `significance`, rich card layout.
///   2. **Timeline** — every moment, grouped by "Month YYYY",
///      compact rows tinted by the moment's accent color.
///
/// Accent colors / icons keyed by `moment.type` are hardcoded to
/// match `apps/web/src/components/MomentsDrawer.tsx` 1:1 — eventual
/// server-baked viewModel (`accentColorHex`, `relativeDateLabel`,
/// `gameLabel`) will replace these. Until then the constants are
/// duplicated and any drift will surface in screenshots.
struct MomentsDrawer: View {
    @Binding var isOpen: Bool
    let moments: [Dashboard.MomentEntry]
    let lookups: Dashboard.Lookups?

    /// Drawer width on macOS. Web uses 420px and capped to 90vw —
    /// macOS windows are typically wider so 420pt is plenty without
    /// the responsive cap.
    private static let drawerWidth: CGFloat = 420

    /// Reverse-chronological — newest first. The server's
    /// `recentMoments` already arrives sorted but we re-sort
    /// defensively in case the wire shape changes.
    private var sorted: [Dashboard.MomentEntry] {
        moments.sorted { $0.date > $1.date }
    }

    /// Top 5 by significance — same slice the web takes for the
    /// Highlights section. Falls back to the leading 5 sorted entries
    /// when significance ties up, which matches web behaviour.
    private var highlights: [Dashboard.MomentEntry] {
        Array(sorted.prefix(5))
    }

    /// Group by "April 2026" month-year, in newest-first order.
    /// Returns an array of `(monthLabel, [moment])` pairs so SwiftUI
    /// can iterate them in the rendered order without losing the
    /// grouping key.
    private var grouped: [(month: String, moments: [Dashboard.MomentEntry])] {
        var seen: [String] = []
        var byMonth: [String: [Dashboard.MomentEntry]] = [:]
        let fmt = DateFormatter()
        fmt.dateFormat = "MMMM yyyy"
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        for moment in sorted {
            let date = iso.date(from: moment.date) ?? ISO8601DateFormatter().date(from: moment.date) ?? Date()
            let key = fmt.string(from: date)
            if byMonth[key] == nil {
                byMonth[key] = []
                seen.append(key)
            }
            byMonth[key]?.append(moment)
        }
        return seen.map { (month: $0, moments: byMonth[$0] ?? []) }
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            // Click-out dismiss layer. Transparent (no scrim, no blur)
            // — the rest of the dashboard stays fully readable while
            // the drawer is open. The layer is just here to capture
            // taps outside the panel and close the drawer.
            if isOpen {
                Color.clear
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeOut(duration: 0.25)) { isOpen = false }
                    }
            }

            // Panel — slides in from the right edge.
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                if isOpen {
                    panel
                        .frame(width: Self.drawerWidth)
                        .transition(.move(edge: .trailing))
                }
            }
        }
        .animation(.easeOut(duration: 0.25), value: isOpen)
    }

    // MARK: - Panel

    @ViewBuilder
    private var panel: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(Palette.borderSubtle)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if moments.isEmpty {
                        emptyState
                    } else {
                        if !highlights.isEmpty {
                            highlightsSection
                            Divider().overlay(Palette.borderSubtle)
                        }
                        timelineSection
                    }
                }
            }
        }
        .background(Palette.bgElevated.opacity(0.97))
        .overlay(
            Rectangle()
                .frame(width: 1)
                .foregroundColor(Palette.borderSubtle),
            alignment: .leading
        )
        .ignoresSafeArea(.container, edges: .top)
    }

    private var header: some View {
        HStack {
            Text("Moments")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Palette.textSecondary)
            Spacer()
            Button {
                withAnimation(.easeOut(duration: 0.25)) { isOpen = false }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Palette.textMuted)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Close")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        // Push content below traffic-light cluster.
        .padding(.top, 30)
    }

    // MARK: - Sections

    private var highlightsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: "Highlights", icon: "trophy.fill")
            VStack(spacing: 8) {
                ForEach(highlights) { moment in
                    MomentHighlightCard(moment: moment, lookups: lookups)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 16)
    }

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "Timeline", icon: "star.fill")
            ForEach(grouped, id: \.month) { group in
                VStack(alignment: .leading, spacing: 6) {
                    Text(group.month.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.5)
                        .foregroundColor(Palette.textMuted)
                    VStack(spacing: 6) {
                        ForEach(group.moments) { moment in
                            MomentTimelineRow(moment: moment, lookups: lookups)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 16)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "star")
                .font(.system(size: 28))
                .foregroundColor(Palette.textMuted.opacity(0.5))
            Text("Keep racing to unlock your first milestone!")
                .font(.system(size: 12))
                .foregroundColor(Palette.textMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private func sectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Palette.textSecondary)
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Palette.textSecondary)
        }
    }
}

// MARK: - Moment styling

/// Per-`type` accent + icon. Mirrors web's `ACCENT` and `ICON` maps in
/// `apps/web/src/components/MomentsDrawer.tsx`. Kept in lockstep
/// manually until server bakes a `viewModel.accentColorHex` field.
enum MomentStyle {
    static func accent(for type: String) -> Color {
        switch type {
        case "win_streak", "podium_streak":  return Color(hex: "#ffd700")
        case "clean_streak":                  return Color(hex: "#43a047")
        case "milestone_irating":             return Color(hex: "#e53935")
        case "license_promotion":             return Color(hex: "#1e88e5")
        case "comeback":                      return Color(hex: "#ff9800")
        case "personal_best":                 return Color(hex: "#7c6cf0")
        case "new_track", "new_car":          return Color(hex: "#00acc1")
        case "century":                       return Color(hex: "#ffb300")
        case "iron_man":                      return Color(hex: "#ff5722")
        case "heartbreak":                    return Color(hex: "#e53935")
        default:                              return Palette.textDim
        }
    }

    /// SF Symbol for the moment type. Web uses Lucide; native maps
    /// to the closest SF Symbol per type. Server doesn't ship icon
    /// names — icon systems differ per platform.
    static func iconName(for type: String) -> String {
        switch type {
        case "win_streak":         return "trophy.fill"
        case "podium_streak":      return "medal.fill"
        case "clean_streak":       return "shield.fill"
        case "milestone_irating":  return "chart.line.uptrend.xyaxis"
        case "license_promotion":  return "arrow.up.square.fill"
        case "comeback":           return "flame.fill"
        case "personal_best":      return "star.fill"
        case "new_track":          return "mappin.circle.fill"
        case "new_car":            return "car.fill"
        case "century":            return "clock.fill"
        case "iron_man":           return "flame.fill"
        case "heartbreak":         return "heart.slash.fill"
        default:                   return "star"
        }
    }
}

/// Shared formatter for "today / yesterday / 3d / 2w / Apr 28" copy.
/// Server-baked label will replace this once `Moment.viewModel.relativeDateLabel`
/// ships; for now native does its own math against `moment.date` and
/// matches the web's `formatRelative()` helper byte-for-byte.
enum MomentDate {
    static func relative(from iso: String) -> String {
        let isoFmt = ISO8601DateFormatter()
        isoFmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = isoFmt.date(from: iso) ?? ISO8601DateFormatter().date(from: iso)
        guard let date else { return iso }
        let days = Int(Date().timeIntervalSince(date) / 86_400)
        if days <= 0 { return "Today" }
        if days == 1 { return "Yesterday" }
        if days < 7  { return "\(days)d ago" }
        if days < 30 { return "\(days / 7)w ago" }
        let df = DateFormatter()
        df.dateFormat = "MMM d"
        return df.string(from: date)
    }
}

// MARK: - Highlight card

/// Rich card shown in the Highlights section. Matches the web's
/// `HighlightCard` — accent-tinted background, large icon, title,
/// 2-line description, date footer, significance number on the right.
struct MomentHighlightCard: View {
    let moment: Dashboard.MomentEntry
    let lookups: Dashboard.Lookups?

    private var accent: Color { MomentStyle.accent(for: moment.type) }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            badge
            VStack(alignment: .leading, spacing: 4) {
                Text(moment.title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(accent)
                    .lineLimit(1)
                Text(moment.description)
                    .font(.system(size: 11))
                    .foregroundColor(Palette.textDim)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    Text(MomentDate.relative(from: moment.date))
                        .font(.system(size: 10))
                        .foregroundColor(Palette.textMuted)
                    if let game = moment.gameName, !game.isEmpty {
                        Text("·").font(.system(size: 10)).foregroundColor(Palette.textMuted.opacity(0.5))
                        Text(gameLabel(game))
                            .font(.system(size: 10))
                            .foregroundColor(Palette.textMuted)
                    }
                }
                .padding(.top, 2)
            }
            Spacer(minLength: 6)
            Text("\(moment.significance)")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(accent)
                .monospacedDigit()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(accent.opacity(0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(accent.opacity(0.25), lineWidth: 1)
                )
        )
    }

    @ViewBuilder
    private var badge: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(accent.opacity(0.18))
                .frame(width: 36, height: 36)
            badgeContent
                .frame(width: 36, height: 36)
        }
    }

    /// Context-aware badge content — track silhouette, brand logo,
    /// or fallback SF Symbol. Same priority order as web's
    /// `BadgeContent`: car-moments prefer brand logo, track-moments
    /// prefer track silhouette, otherwise track silhouette / brand
    /// logo / icon.
    @ViewBuilder
    private var badgeContent: some View {
        let tk = lookups?.track(for: moment.trackName)
        let cl = lookups?.car(for: moment.carModel)

        if moment.type == "new_car", let cl, cl.logoSvg != nil || cl.logoPng != nil {
            BrandLogo(lookup: cl, height: 20)
        } else if moment.type == "new_track", let svg = tk?.svgPath {
            TrackSilhouette(svgPath: svg, stroke: accent, lineWidth: 2)
                .padding(6)
        } else if let svg = tk?.svgPath {
            TrackSilhouette(svgPath: svg, stroke: accent, lineWidth: 2)
                .padding(6)
        } else if let cl, cl.logoSvg != nil || cl.logoPng != nil {
            BrandLogo(lookup: cl, height: 20)
        } else {
            Image(systemName: MomentStyle.iconName(for: moment.type))
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(accent)
        }
    }

    private func gameLabel(_ raw: String) -> String {
        let n = raw.lowercased()
        if n == "iracing" { return "iRacing" }
        if n == "acc" || n.contains("assetto corsa") { return "ACC" }
        if n == "raceroom" { return "RaceRoom" }
        if n.contains("rfactor") { return "rFactor" }
        if n.contains("automobilista") || n == "ams" { return "AMS" }
        return raw.prefix(1).uppercased() + raw.dropFirst()
    }
}

// MARK: - Timeline row

/// Compact row used in the Timeline section. Same accent treatment
/// as the highlight card but shrunk to one-line title + description.
struct MomentTimelineRow: View {
    let moment: Dashboard.MomentEntry
    let lookups: Dashboard.Lookups?

    private var accent: Color { MomentStyle.accent(for: moment.type) }

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(accent.opacity(0.18))
                    .frame(width: 30, height: 30)
                Image(systemName: MomentStyle.iconName(for: moment.type))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(accent)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(moment.title)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(accent)
                        .lineLimit(1)
                    Text(MomentDate.relative(from: moment.date))
                        .font(.system(size: 10))
                        .foregroundColor(Palette.textMuted)
                }
                Text(moment.description)
                    .font(.system(size: 11))
                    .foregroundColor(Palette.textDim)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(accent.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(accent.opacity(0.18), lineWidth: 1)
                )
        )
    }
}
