import SwiftUI

/// Compact horizontal stat ticker modeled on the web `/drive` DataStrip.
///
/// Every column shares the same two-row structure:
///     LABEL (small caps)
///     <value row>
/// where the value row is just a number for plain stats (RACES, LAPS,
/// SPAN, TRACKS, CARS) and <value> <license badge> <sparkline inline>
/// for iRating columns. Keeping the label row at the same Y position
/// across all columns is what made the web's DataStrip feel aligned —
/// the previous version stacked the sparkline below the number in the
/// iRating columns, which threw off the visual row.
struct DataStrip: View {
    let dashboard: Dashboard?
    let safetyRating: [String: Dashboard.SafetyRatingData]?

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            stat("RACES", value: "\(dashboard?.stats.totalRaces ?? 0)")
            divider
            stat("LAPS", value: "\(dashboard?.stats.totalLaps ?? 0)")

            ForEach(dashboard?.activeCategories ?? [], id: \.key) { entry in
                divider
                iRatingColumn(
                    label: entry.label,
                    rating: entry.rating,
                    license: safetyRating?[entry.key]
                )
            }

            divider
            stat("SPAN", value: spanText)
            divider
            stat("TRACKS", value: "\(dashboard?.stats.uniqueTracks ?? 0)")
            divider
            stat("CARS", value: "\(dashboard?.stats.uniqueCars ?? 0)")

            // Eats any remaining horizontal space so the strip fills the
            // detail column edge-to-edge and the hairline underline spans
            // the full width instead of ending under "CARS".
            Spacer(minLength: 0)
        }
        // Zero leading padding so the first column (RACES) sits flush
        // against the detail view's left edge — that's what makes the
        // strip feel connected to the rail on its left. Trailing
        // padding kept so the last column has breathing room before
        // the sidebar.
        .padding(.leading, 0)
        .padding(.trailing, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 56)
        // Hairline at the TOP edge — the strip is bottom-aligned in the
        // detail view, so the line separates it from the scrolling
        // content above rather than sitting under it as a header rule.
        .overlay(alignment: .top) {
            Rectangle().fill(Palette.borderSubtle).frame(height: 1)
        }
    }

    // MARK: - Columns

    /// Plain label-over-value column.
    private func stat(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.9)
                .foregroundColor(Palette.textDim)
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(Palette.textPrimary)
        }
        .frame(minWidth: 54, alignment: .leading)
        .padding(.horizontal, 14)
    }

    /// iRating column. Label on top matches the plain stats. Content row
    /// is value + license badge + inline sparkline — all on one
    /// baseline so the strip reads as a single row.
    private func iRatingColumn(
        label: String,
        rating: Dashboard.IRatingData,
        license: Dashboard.SafetyRatingData?
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.9)
                .foregroundColor(Palette.textDim)

            HStack(alignment: .center, spacing: 8) {
                Text(rating.current.map { "\($0)" } ?? "—")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(Palette.textPrimary)

                if let badge = licenseBadge(from: license) {
                    LicenseBadge(label: badge.text, tint: badge.tint)
                }

                Sparkline(
                    values: rating.sparkline.map(\.value),
                    trend: rating.trend,
                    lineWidth: 1.2,
                    showFill: false
                )
                .frame(width: 120, height: 22)
            }
        }
        .padding(.horizontal, 14)
    }

    private var divider: some View {
        Rectangle()
            .fill(Palette.borderSubtle)
            .frame(width: 1, height: 32)
    }

    // MARK: - Derived

    private var spanText: String {
        let days = dashboard?.stats.careerSpanDays ?? 0
        if days == 0 { return "—" }
        if days < 60 { return "\(days)d" }
        let months = days / 30
        if months < 24 { return "\(months)mo" }
        return "\(months / 12)y"
    }

    /// Turn a safety-rating row into an on-screen badge like "B0.58".
    /// Returns nil when class is missing — we'd rather omit the badge
    /// than show a placeholder.
    private func licenseBadge(
        from sr: Dashboard.SafetyRatingData?
    ) -> (text: String, tint: Color)? {
        guard let sr, let cls = sr.license else { return nil }
        let srValue = sr.current ?? 0
        let text = String(format: "%@%.2f", cls, srValue)
        let tint: Color
        switch cls {
        case "A": tint = Color(hex: "#7cdff0")
        case "B": tint = Color(hex: "#6fcf69")
        case "C": tint = Color(hex: "#ffcf4a")
        case "D": tint = Color(hex: "#ff8c42")
        default:   tint = Palette.brand
        }
        return (text, tint)
    }
}

/// Small filled pill showing a license class + SR number. Sized for
/// inline placement within a text row — height ≈ digit cap height so
/// it sits on the same baseline as adjacent numerals.
struct LicenseBadge: View {
    let label: String
    let tint: Color
    var body: some View {
        Text(label)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundColor(Color.black.opacity(0.82))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(tint)
            )
    }
}
