import SwiftUI

// MARK: - Tab switcher

/// Segmented-like tab picker matching the web dashboard's
/// "Performance | Next Race | Previous Races" row.
enum DashboardTab: String, CaseIterable {
    case performance = "Performance"
    case nextRace = "Next Race"
    case previous = "Previous Races"

    var icon: String {
        switch self {
        case .performance: return "chart.bar"
        case .nextRace: return "flag"
        case .previous: return "clock.arrow.circlepath"
        }
    }
}

struct DashboardTabs: View {
    @Binding var selection: DashboardTab
    var body: some View {
        HStack(spacing: 4) {
            ForEach(DashboardTab.allCases, id: \.self) { tab in
                let isActive = tab == selection
                Button {
                    selection = tab
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 11, weight: .medium))
                        Text(tab.rawValue)
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .foregroundColor(isActive ? Palette.textPrimary : Palette.textDim)
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(isActive ? Palette.brand : Color.clear)
                            .frame(height: 2)
                            .offset(y: 8)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Should You Race Right Now?

/// Advisory panel mirroring the web's "Should You Race Right Now?"
/// module. Displays a status verdict (Good / Marginal / Bad) with a
/// data-backed one-liner. Backed by the server's `when` profile
/// (peak/worst hours, incident rate) — details elided here; if the
/// payload isn't present the panel hides itself gracefully.
struct ShouldYouRacePanel: View {
    enum Verdict { case good, marginal, bad, unknown }
    let verdict: Verdict
    let title: String
    let reason: String

    private var icon: String {
        switch verdict {
        case .good:     return "checkmark.circle.fill"
        case .marginal: return "exclamationmark.circle.fill"
        case .bad:      return "xmark.octagon.fill"
        case .unknown:  return "questionmark.circle"
        }
    }
    private var tint: Color {
        switch verdict {
        case .good:     return Palette.success
        case .marginal: return Color(hex: "#ffcf4a")
        case .bad:      return Palette.brand
        case .unknown:  return Palette.textDim
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(tint)
            VStack(alignment: .leading, spacing: 4) {
                Text("SHOULD YOU RACE RIGHT NOW?")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.2)
                    .foregroundColor(Palette.textDim)
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(title)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(tint)
                    Text(reason)
                        .font(.system(size: 12))
                        .foregroundColor(Palette.textSecondary)
                        .lineLimit(2)
                }
            }
            Spacer()
            Image(systemName: "chevron.down")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Palette.textDim)
        }
        .panel(
            border: tint.opacity(0.35),
            cornerRadius: 10,
            padding: 14
        )
    }
}

// MARK: - Strengths / Watch Out

/// Two-column panel matching the web's Strengths/Watch Out section.
/// Each side shows a time-window header (e.g. "Wednesdays 7pm-10pm") +
/// a prose summary + a bulleted insights list.
struct StrengthsWatchOutPanel: View {
    struct Side {
        let label: String                  // "STRENGTHS" / "WATCH OUT"
        let tint: Color                    // green / red
        let window: String                 // "Wednesdays\n7pm – 10pm"
        let footnote: String?              // "avg +383 iR"
        let summary: String                // prose paragraph
        let bullets: [String]              // list of callouts
    }

    let strengths: Side
    let watchOut: Side

    var body: some View {
        HStack(alignment: .top, spacing: 24) {
            column(strengths, icon: "minus")
            column(watchOut, icon: "arrow.down.right")
        }
        .panel()
    }

    private func column(_ s: Side, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(s.label.uppercased())
                .font(.system(size: 10, weight: .bold))
                .tracking(1.2)
                .foregroundColor(s.tint)

            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(s.window)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Palette.textPrimary)
                    if let foot = s.footnote {
                        Text(foot)
                            .font(.system(size: 10))
                            .foregroundColor(Palette.textDim)
                    }
                }
                .frame(minWidth: 110, alignment: .leading)

                Text(s.summary)
                    .font(.system(size: 12))
                    .foregroundColor(Palette.textSecondary)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Divider + bullets are hidden when the column has no
            // insights yet — otherwise the panel shows a lonely hairline
            // over empty whitespace (which was the "Coming soon" block's
            // main wonk).
            if !s.bullets.isEmpty {
                Divider().overlay(Palette.borderSubtle)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(s.bullets, id: \.self) { b in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: icon)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(s.tint.opacity(0.9))
                                .padding(.top, 3)
                            Text(b)
                                .font(.system(size: 12))
                                .foregroundColor(Palette.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Viz placeholders

/// Panels for the three visualizations that aren't implemented yet:
/// Race Calendar heatmap, Race Schedule scatter, Driver DNA radar.
/// Show the right chrome (header + icon) with a "data loading" hint so
/// the dashboard layout is visually complete; swap each with a real
/// Canvas-driven chart in a follow-up pass.
struct VizPlaceholder: View {
    let title: String
    let subtitle: String?
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Palette.textDim)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Palette.textPrimary)
                Spacer()
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundColor(Palette.textDim)
                }
            }

            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Palette.bgBase.opacity(0.3))
                .overlay(
                    HStack(spacing: 8) {
                        Image(systemName: icon)
                            .font(.system(size: 14))
                            .foregroundColor(Palette.textMuted)
                        Text("Coming soon")
                            .font(.system(size: 11))
                            .foregroundColor(Palette.textMuted)
                    }
                )
                .frame(height: 96)
        }
        .panel(padding: 14)
    }
}

// MARK: - Right sidebar

/// Tabbed sidebar with Tracks / Cars lists. Each row shows a
/// number, a thumbnail placeholder (real silhouettes TBD), the name,
/// and a compact stats line (sessions, best pos, mastery multiplier).
struct SidebarTabs: View {
    enum Tab: String, CaseIterable { case tracks = "Tracks", cars = "Cars" }

    @State private var selection: Tab = .tracks
    let tracks: [Dashboard.TrackMasteryEntry]
    let cars: [Dashboard.CarAffinityEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row — 44pt fixed height so the tab labels and
            // hairline divider line up exactly with the main column's
            // tabs + divider. Any difference here shows as a visible
            // Z-offset between the two headers.
            HStack(spacing: 14) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    let isActive = tab == selection
                    Button {
                        selection = tab
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: tab == .tracks ? "map" : "car.2")
                                .font(.system(size: 11, weight: .medium))
                            Text(tab.rawValue)
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(isActive ? Palette.textPrimary : Palette.textDim)
                        .overlay(alignment: .bottom) {
                            Rectangle()
                                .fill(isActive ? Palette.brand : Color.clear)
                                .frame(height: 2)
                                .offset(y: 12)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(.horizontal, 14)
            .frame(height: 44)

            Divider().overlay(Palette.borderSubtle)

            ScrollView {
                VStack(spacing: 10) {
                    switch selection {
                    case .tracks:
                        if tracks.isEmpty {
                            Text("No track data yet")
                                .font(.system(size: 11))
                                .foregroundColor(Palette.textDim)
                                .padding(.top, 30)
                        } else {
                            ForEach(Array(tracks.enumerated()), id: \.element.id) { idx, track in
                                TrackSidebarCard(rank: idx + 1, track: track)
                            }
                        }
                    case .cars:
                        if cars.isEmpty {
                            Text("No car data yet")
                                .font(.system(size: 11))
                                .foregroundColor(Palette.textDim)
                                .padding(.top, 30)
                        } else {
                            ForEach(Array(cars.enumerated()), id: \.element.id) { idx, car in
                                CarSidebarCard(rank: idx + 1, car: car)
                            }
                        }
                    }
                }
                .padding(.top, 14)
                .padding(.horizontal, 10)
                .padding(.bottom, 20)
            }
        }
    }
}

/// Track card for the right sidebar. Shows rank number, an outline
/// placeholder for the track silhouette (real map TBD), the name, a
/// mastery progress bar, and a stats line.
struct TrackSidebarCard: View {
    let rank: Int
    let track: Dashboard.TrackMasteryEntry

    private var tierColor: Color {
        switch track.masteryTier {
        case "diamond": return Color(hex: "#7cdff0")
        case "gold":    return Color(hex: "#ffcf4a")
        case "silver":  return Color(hex: "#d0d0dc")
        default:        return Color(hex: "#cd7f32")
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(rank)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(Palette.textDim)
                .frame(width: 18, alignment: .leading)

            // Track outline thumbnail — placeholder until we have real
            // track silhouettes bundled.
            Image(systemName: "map")
                .font(.system(size: 24))
                .foregroundColor(Palette.textMuted)
                .frame(width: 40, height: 30)

            VStack(alignment: .leading, spacing: 6) {
                Text(track.trackName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Palette.textPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                // Mastery bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Palette.borderSubtle)
                            .frame(height: 2)
                        Rectangle()
                            .fill(tierColor)
                            .frame(width: geo.size.width * CGFloat(track.masteryScore / 100.0), height: 2)
                    }
                }
                .frame(height: 2)
                HStack(spacing: 6) {
                    Text("\(track.totalSessions) races").foregroundColor(Palette.textDim)
                    if let best = track.bestPosition {
                        Text("P\(best)").foregroundColor(Palette.textDim)
                    }
                    let avg = track.avgPosition.map { String(format: "%.1fx", $0) } ?? "—"
                    Text(avg).foregroundColor(Palette.textDim)
                    Spacer()
                }
                .font(.system(size: 10))
            }
            Circle()
                .fill(tierColor)
                .frame(width: 6, height: 6)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Palette.bgPanel)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Palette.borderSubtle, lineWidth: 1)
        )
    }
}

/// Car card — matches the TrackSidebarCard layout but shows manufacturer
/// instead of track.
struct CarSidebarCard: View {
    let rank: Int
    let car: Dashboard.CarAffinityEntry

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(rank)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(Palette.textDim)
                .frame(width: 18, alignment: .leading)

            Image(systemName: "car.2.fill")
                .font(.system(size: 22))
                .foregroundColor(Palette.brand)
                .frame(width: 40, height: 30)

            VStack(alignment: .leading, spacing: 6) {
                Text(car.manufacturer)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Palette.textPrimary)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle().fill(Palette.borderSubtle).frame(height: 2)
                        Rectangle().fill(Palette.brand).frame(
                            width: geo.size.width * CGFloat(car.affinityScore / 100.0),
                            height: 2
                        )
                    }
                }
                .frame(height: 2)
                HStack(spacing: 6) {
                    Text("\(car.totalSessions) races").foregroundColor(Palette.textDim)
                    if let best = car.bestPosition {
                        Text("P\(best)").foregroundColor(Palette.textDim)
                    }
                    Spacer()
                }
                .font(.system(size: 10))
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Palette.bgPanel)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Palette.borderSubtle, lineWidth: 1)
        )
    }
}
