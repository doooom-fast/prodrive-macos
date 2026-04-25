import SwiftUI

// MARK: - Race Calendar (weekly grid)

/// Monthly calendar heatmap — rows = weeks, columns = weekdays (M…S),
/// cells colored by session count on that specific date. Mirrors the
/// web's `RaceCalendarHeatmap`: lets you scan "when have I been
/// racing" at a glance.
///
/// Sourced from `poller.sessions` rather than `when.heatmapData`,
/// because heatmapData aggregates by day-of-week × hour-of-day — it
/// loses the specific-date axis the calendar needs.
struct RaceCalendarHeatmap: View {
    let sessions: [Dashboard.RecentSession]

    private static let dayLabels = ["M", "T", "W", "T", "F", "S", "S"]

    /// How many calendar weeks we display. 6 matches the web's
    /// Race Calendar which shows an entire season-month window.
    private static let weekRows = 6

    /// Sessions-per-date map for quick lookup during grid render.
    private var sessionsByDay: [Date: Int] {
        let cal = Calendar.current
        var out: [Date: Int] = [:]
        for s in sessions {
            let key = cal.startOfDay(for: s.startTime)
            out[key, default: 0] += 1
        }
        return out
    }

    /// Grid origin: start of the week, N weeks ago. Aligned to Monday
    /// so the column layout matches the server's Mon-first ordering.
    private var gridStartDate: Date {
        var cal = Calendar.current
        cal.firstWeekday = 2  // Monday
        let today = Date()
        let weekStart = cal.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        return cal.date(byAdding: .weekOfYear, value: -(Self.weekRows - 1), to: weekStart) ?? today
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "calendar")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Palette.textDim)
                Text("Race Calendar")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Palette.textPrimary)
                Spacer()
                Text(monthLabel)
                    .font(.system(size: 10))
                    .foregroundColor(Palette.textDim)
            }

            VStack(spacing: 4) {
                // Weekday header row
                HStack(spacing: 4) {
                    ForEach(Self.dayLabels.indices, id: \.self) { i in
                        Text(Self.dayLabels[i])
                            .font(.system(size: 9, weight: .semibold))
                            .tracking(0.6)
                            .foregroundColor(Palette.textDim)
                            .frame(maxWidth: .infinity)
                    }
                }

                // Week rows × 7 day cells
                ForEach(0..<Self.weekRows, id: \.self) { week in
                    HStack(spacing: 4) {
                        ForEach(0..<7, id: \.self) { day in
                            dayCell(week: week, day: day)
                        }
                    }
                }
            }
        }
        .panel(padding: 14)
    }

    private func dayCell(week: Int, day: Int) -> some View {
        let cal = Calendar.current
        let cellDate = cal.date(
            byAdding: .day,
            value: week * 7 + day,
            to: gridStartDate
        ) ?? gridStartDate
        let sessionCount = sessionsByDay[cal.startOfDay(for: cellDate)] ?? 0
        let intensity = min(1.0, Double(sessionCount) / 3.0)  // 3+ saturates
        let isFuture = cellDate > Date()

        return RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(cellFill(intensity: intensity, isFuture: isFuture))
            .frame(height: 20)
            .overlay(
                Group {
                    if sessionCount > 0 {
                        Text("\(sessionCount)")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.85))
                    }
                }
            )
    }

    private func cellFill(intensity: Double, isFuture: Bool) -> Color {
        if isFuture { return Palette.borderSubtle.opacity(0.15) }
        if intensity == 0 { return Palette.bgBase.opacity(0.4) }
        return Color(hex: "#b02020").opacity(0.2 + 0.7 * intensity)
    }

    private var monthLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter.string(from: Date())
    }
}

// MARK: - Race Schedule (hour × day scatter)

/// Scatter chart with time-of-day on Y (labeled rows: 3AM / 6AM /
/// 9AM / 12PM / 3PM / 6PM / 9PM) and day-of-week on X (Mon–Sun).
/// Consumes the server's pre-bucketed `scatterBuckets` directly —
/// same data + bucketing as the web's `RaceScatterGrid`. Dot size
/// scales with session count, color scales with avg incidents per
/// bucket using the web's red ramp (low→mid→high).
struct RaceScheduleScatter: View {
    let buckets: [Dashboard.ScatterBucket]

    /// Server buckets use JS day convention (0=Sun … 6=Sat). The
    /// web's scatter display order is Mon..Sun, so we remap the x
    /// column at render time.
    private static let displayDayOrder = [1, 2, 3, 4, 5, 6, 0]
    private static let dayLabels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    /// Y-axis hour ticks matching the web's grid lines.
    private static let hourTicks: [(hour: Int, label: String)] = [
        (3, "3 AM"),
        (6, "6 AM"),
        (9, "9 AM"),
        (12, "12 PM"),
        (15, "3 PM"),
        (18, "6 PM"),
        (21, "9 PM"),
    ]

    /// Web component uses min-hour/max-hour cropping to the data
    /// range. Native expands to a fixed 0–24 window so the grid
    /// aligns with the tick labels regardless of when the user races.
    private static let minHour: Int = 0
    private static let maxHour: Int = 24

    /// Web's dot radius bounds (`MIN_R` / `MAX_R` in RaceScatterGrid.tsx).
    private static let minRadius: CGFloat = 4
    private static let maxRadius: CGFloat = 14

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "clock")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Palette.textDim)
                Text("Race Schedule")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Palette.textPrimary)
                Spacer()
                Text("Incidents")
                    .font(.system(size: 10))
                    .foregroundColor(Palette.textDim)
            }

            if buckets.isEmpty {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Palette.bgBase.opacity(0.3))
                    .frame(height: 220)
                    .overlay(
                        Text("Run a few sessions to chart your schedule")
                            .font(.system(size: 10))
                            .foregroundColor(Palette.textMuted)
                    )
            } else {
                scatterGrid
            }
        }
        .panel(padding: 14)
    }

    private var scatterGrid: some View {
        HStack(alignment: .top, spacing: 8) {
            // Y-axis: hour labels aligned to grid-line positions so
            // each label lives at exactly the Y it describes.
            GeometryReader { geo in
                ForEach(Self.hourTicks, id: \.hour) { tick in
                    Text(tick.label)
                        .font(.system(size: 9))
                        .foregroundColor(Palette.textDim)
                        .position(
                            x: geo.size.width / 2,
                            y: yForTick(tick.hour, in: geo.size.height))
                }
            }
            .frame(width: 36, height: 260)

            GeometryReader { geo in
                let maxCount = CGFloat(max(1, buckets.map { $0.count }.max() ?? 1))
                let minInc = buckets.map { $0.avgIncidents }.min() ?? 0
                let maxInc = buckets.map { $0.avgIncidents }.max() ?? 1
                // Inset matches MAX_R so the largest dot fits fully
                // inside the plot rather than clipping at any edge.
                let plotInset: CGFloat = Self.maxRadius + 2
                let plotWidth = geo.size.width - plotInset * 2
                let plotHeight = geo.size.height - plotInset * 2
                let colW = plotWidth / 7

                Canvas { ctx, _ in
                    // Horizontal grid lines at each hour tick.
                    for tick in Self.hourTicks {
                        let y = plotInset + yForHour(tick.hour, height: plotHeight)
                        var line = Path()
                        line.move(to: CGPoint(x: plotInset, y: y))
                        line.addLine(to: CGPoint(x: plotInset + plotWidth, y: y))
                        ctx.stroke(line, with: .color(Palette.borderSubtle.opacity(0.45)), lineWidth: 0.5)
                    }

                    for bucket in buckets {
                        guard bucket.count > 0 else { continue }
                        guard let column = Self.displayDayOrder.firstIndex(of: bucket.day) else { continue }
                        let x = plotInset + colW * CGFloat(column) + colW / 2
                        let y = plotInset + yForHour(bucket.hour, height: plotHeight)

                        // Web radius rule: sqrt(count/maxCount) scaled
                        // between MIN_R and MAX_R.
                        let sizeT = sqrt(CGFloat(bucket.count) / maxCount)
                        let radius = Self.minRadius + (Self.maxRadius - Self.minRadius) * sizeT

                        let dot = Path(ellipseIn: CGRect(
                            x: x - radius, y: y - radius,
                            width: radius * 2, height: radius * 2))
                        ctx.fill(dot, with: .color(incidentColor(
                            avg: bucket.avgIncidents,
                            min: minInc,
                            max: maxInc)))
                    }
                }
            }
            .frame(height: 260)
            .overlay(alignment: .bottom) {
                HStack(spacing: 0) {
                    ForEach(Self.dayLabels.indices, id: \.self) { i in
                        Text(Self.dayLabels[i])
                            .font(.system(size: 9, weight: .semibold))
                            .tracking(0.6)
                            .foregroundColor(Palette.textDim)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, Self.maxRadius + 2)
                .offset(y: 14)
            }
        }
    }

    private func yForHour(_ hour: Int, height: CGFloat) -> CGFloat {
        let range = CGFloat(Self.maxHour - Self.minHour)
        return (CGFloat(hour - Self.minHour) / range) * height
    }

    /// Label Y aligned to the same inset the plot uses — otherwise
    /// hour labels drift from the grid line they describe.
    private func yForTick(_ hour: Int, in fullHeight: CGFloat) -> CGFloat {
        let plotInset: CGFloat = Self.maxRadius + 2
        let plotHeight = fullHeight - plotInset * 2
        return plotInset + yForHour(hour, height: plotHeight)
    }

    /// Color ramp matches the web: dark-red → mid-red → bright-red
    /// as avg-incidents increases. Default metric is "incidents" so
    /// high values are always the brightest red.
    private func incidentColor(avg: Double, min: Double, max: Double) -> Color {
        let range = max - min
        let t = range > 0 ? (avg - min) / range : 0
        let low  = (r: 0.44, g: 0.00, b: 0.06)   // #700010
        let mid  = (r: 0.69, g: 0.13, b: 0.13)   // #b02020
        let high = (r: 0.90, g: 0.22, b: 0.21)   // #e53935
        func lerp(_ a: Double, _ b: Double, _ f: Double) -> Double { a + (b - a) * f }
        let color: (r: Double, g: Double, b: Double)
        if t < 0.5 {
            let f = t / 0.5
            color = (lerp(low.r, mid.r, f), lerp(low.g, mid.g, f), lerp(low.b, mid.b, f))
        } else {
            let f = (t - 0.5) / 0.5
            color = (lerp(mid.r, high.r, f), lerp(mid.g, high.g, f), lerp(mid.b, high.b, f))
        }
        return Color(.sRGB, red: color.r, green: color.g, blue: color.b, opacity: 1)
    }
}

// MARK: - Driver DNA (8-axis radar with archetype)

/// 8-axis polar radar rendered from server-pre-computed values.
/// Axis values + archetype label come straight from the dashboard
/// payload — same `computeDriverDNA` / `getDriverArchetype` lib the
/// web component uses. Zero Swift-side computation.
struct DriverDNARadar: View {
    let dashboard: Dashboard?

    private struct Axis {
        let label: String
        let value: Double   // 0–100
    }

    private var axes: [Axis] {
        guard let d = dashboard?.driverDNA else {
            return Self.axisLabels.map { Axis(label: $0, value: 0) }
        }
        // Match the exact ordering used by the web's DriverDNARadar
        // (Consistency first, Experience last — clockwise from top).
        // Wet is always included here even when the value is 50 (the
        // placeholder neutral) so the polygon count stays at 8 for
        // visual consistency across users.
        return [
            Axis(label: "Consistency",  value: d.consistency),
            Axis(label: "Racecraft",    value: d.racecraft),
            Axis(label: "Cleanness",    value: d.cleanness),
            Axis(label: "Endurance",    value: d.endurance),
            Axis(label: "Adaptability", value: d.adaptability),
            Axis(label: "Improvement",  value: d.improvement),
            Axis(label: "Wet",          value: d.wetWeather),
            Axis(label: "Experience",   value: d.experience),
        ]
    }

    private static let axisLabels = [
        "Consistency", "Racecraft", "Cleanness", "Endurance",
        "Adaptability", "Improvement", "Wet", "Experience",
    ]

    /// Archetype from the server — not computed locally.
    private var archetype: (primary: String, secondary: String, description: String?) {
        guard let a = dashboard?.driverArchetype else {
            return ("Learning the ropes", "Rookie", nil)
        }
        return (a.variant, a.major, a.variantDescription)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "atom")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Palette.textDim)
                Text("Driver DNA")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Palette.textPrimary)
                Spacer()
            }

            // Archetype header — variant (bold), major (dim), and
            // optional description. Matches the web's typography +
            // copy exactly; text comes from the server's
            // `getDriverArchetype` result.
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(archetype.primary)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Palette.textSecondary)
                    Text(archetype.secondary)
                        .font(.system(size: 11))
                        .foregroundColor(Palette.textDim)
                }
                if let description = archetype.description, !description.isEmpty {
                    Text(description)
                        .font(.system(size: 11))
                        .italic()
                        .foregroundColor(Palette.textDim)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            GeometryReader { geo in
                // Radar fills the available space up to a 420pt cap so
                // it never shrinks to thumbnail size on wide windows.
                // Previous version hardcoded a 180pt frame + min(w,h),
                // which made the shape tiny in the full-width card.
                let side = min(min(geo.size.width, geo.size.height), 420)
                let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                let radius = side / 2 - 32

                Canvas { ctx, _ in
                    let a = axes
                    guard a.count >= 3 else { return }
                    let count = a.count

                    func point(i: Int, distance: CGFloat) -> CGPoint {
                        let angle = CGFloat(i) / CGFloat(count) * 2 * .pi - .pi / 2
                        return CGPoint(
                            x: center.x + cos(angle) * distance,
                            y: center.y + sin(angle) * distance)
                    }

                    // Grid rings (25/50/75/100)
                    for ring in [0.25, 0.5, 0.75, 1.0] {
                        var p = Path()
                        for i in 0..<count {
                            let pt = point(i: i, distance: radius * CGFloat(ring))
                            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
                        }
                        p.closeSubpath()
                        ctx.stroke(p, with: .color(Palette.borderSubtle.opacity(0.7)), lineWidth: 0.5)
                    }

                    // Spokes
                    for i in 0..<count {
                        var s = Path()
                        s.move(to: center)
                        s.addLine(to: point(i: i, distance: radius))
                        ctx.stroke(s, with: .color(Palette.borderSubtle.opacity(0.5)), lineWidth: 0.5)
                    }

                    // Data polygon
                    var dataPath = Path()
                    for i in 0..<count {
                        let pt = point(i: i, distance: radius * CGFloat(a[i].value / 100.0))
                        if i == 0 { dataPath.move(to: pt) } else { dataPath.addLine(to: pt) }
                    }
                    dataPath.closeSubpath()
                    ctx.fill(dataPath, with: .color(Palette.brand.opacity(0.28)))
                    ctx.stroke(dataPath, with: .color(Palette.brand), lineWidth: 1.2)

                    // Axis labels
                    for i in 0..<count {
                        let pt = point(i: i, distance: radius + 12)
                        ctx.draw(
                            Text(a[i].label)
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundColor(Palette.textDim),
                            at: pt)
                    }
                }
            }
            .frame(height: 180)
        }
        .panel(padding: 14)
    }
}
