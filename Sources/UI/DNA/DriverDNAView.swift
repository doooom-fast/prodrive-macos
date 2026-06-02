import SwiftUI

/// Full Driver DNA destination — mirrors the web's `DriverDNAPage.tsx`.
/// Hero with archetype + variant + description (overlaid by a faint
/// large radar), then a 2-column grid of 8 dimension cards rendered
/// straight from `dashboard.dnaInsights`.
///
/// Empty state matches the web: hero copy + "race 3+ to unlock"
/// callout when the server hasn't computed a DNA profile yet.
struct DriverDNAView: View {
    @ObservedObject private var poller: DashboardPoller

    @MainActor
    init() { self.poller = .shared }

    private var dashboard: Dashboard? { poller.latest }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                hero
                if dashboard?.driverDNA == nil {
                    emptyCard
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                } else {
                    insightsGrid
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                        .padding(.bottom, 30)
                }
            }
        }
    }

    // MARK: - Hero

    /// Hero band — eyebrow + title + variant headline + major label
    /// + description. Faint full-bleed radar sits at the bottom-right
    /// when DNA is available, the same decorative trick the web uses.
    private var hero: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Performance Profile")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(2)
                    .foregroundColor(Palette.textMuted)
                    .padding(.bottom, 6)
                Text("Driver DNA")
                    .font(.system(size: 30, weight: .heavy))
                    .foregroundColor(Palette.textPrimary)
                if let archetype = dashboard?.driverArchetype {
                    Text(archetype.variant)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Palette.brand)
                    Text(archetype.major)
                        .font(.system(size: 12))
                        .foregroundColor(Palette.textMuted)
                    if let desc = archetype.variantDescription, !desc.isEmpty {
                        Text(desc)
                            .font(.system(size: 12))
                            .italic()
                            .foregroundColor(Palette.textSecondary)
                            .lineLimit(4)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 4)
                            .frame(maxWidth: 520, alignment: .leading)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 30)
            .padding(.bottom, 28)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.bgPanel.opacity(0.5))

            // Faint background radar — only rendered when DNA exists.
            if dashboard?.driverDNA != nil {
                DriverDNARadarShape(dashboard: dashboard, stroke: Palette.brand.opacity(0.25), fill: Palette.brand.opacity(0.10))
                    .frame(width: 280, height: 280)
                    .padding(.trailing, 30)
                    .padding(.bottom, 8)
                    .opacity(0.55)
                    .allowsHitTesting(false)
            }
        }
    }

    // MARK: - Insights grid

    private var insightsGrid: some View {
        let insights = dashboard?.dnaInsights ?? []
        return LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 14),
                GridItem(.flexible(), spacing: 14),
            ],
            alignment: .leading,
            spacing: 14
        ) {
            ForEach(insights) { insight in
                DNAInsightCard(insight: insight)
            }
        }
    }

    // MARK: - Empty card

    private var emptyCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "scope")
                .font(.system(size: 32))
                .foregroundColor(Palette.brand.opacity(0.6))
            Text("Complete at least 3 races to generate your Driver DNA profile")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Palette.textPrimary)
                .multilineTextAlignment(.center)
            if let stats = dashboard?.stats {
                Text("You currently have \(stats.totalRaces) race\(stats.totalRaces == 1 ? "" : "s") logged. Keep racing and your profile will unlock.")
                    .font(.system(size: 12))
                    .foregroundColor(Palette.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 50)
        .panel()
    }
}

// MARK: - Insight card

/// Single 8-axis dimension card. Header row with axis-icon + label +
/// numeric score, gradient progress bar, description, and trend chip.
struct DNAInsightCard: View {
    let insight: Dashboard.DNAInsight

    private var trendColor: Color {
        switch insight.trend {
        case "improving": return Color(hex: "#43c772")
        case "declining": return Color(hex: "#e35353")
        default:           return Palette.textMuted
        }
    }
    private var trendLabel: String {
        switch insight.trend {
        case "improving": return "Improving"
        case "declining": return "Declining"
        default:           return "Stable"
        }
    }
    private var trendIcon: String {
        switch insight.trend {
        case "improving": return "arrow.up.right"
        case "declining": return "arrow.down.right"
        default:           return "minus"
        }
    }

    /// SF Symbol mapping per axis. Web uses Lucide; native maps each
    /// dimension to the closest SF Symbol — same approach as the
    /// strategy / moments icon dictionaries.
    private var icon: String {
        switch insight.dimension {
        case "consistency":  return "scope"
        case "racecraft":    return "figure.fencing"
        case "cleanness":    return "shield"
        case "endurance":    return "stopwatch"
        case "adaptability": return "shuffle"
        case "improvement":  return "chart.line.uptrend.xyaxis"
        case "wetWeather":   return "cloud.rain"
        case "experience":   return "star"
        default:             return "circle"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Palette.brand)
                    Text(insight.label)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Palette.textPrimary)
                }
                Spacer()
                Text("\(Int(insight.value.rounded()))")
                    .font(.system(size: 16, weight: .bold))
                    .monospacedDigit()
                    .foregroundColor(Palette.brand)
            }

            // Progress bar — gradient from brand at full opacity to
            // ~30% at the trailing edge, matching the web treatment.
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Palette.borderSubtle)
                        .frame(height: 6)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Palette.brand, Palette.brand.opacity(0.35)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(
                            width: max(0, geo.size.width * CGFloat(min(max(insight.value, 0), 100) / 100.0)),
                            height: 6
                        )
                }
            }
            .frame(height: 6)

            Text(insight.description)
                .font(.system(size: 11))
                .foregroundColor(Palette.textDim)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 4) {
                Image(systemName: trendIcon)
                    .font(.system(size: 9, weight: .bold))
                Text(trendLabel)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundColor(trendColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(trendColor.opacity(0.13)))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .panel(padding: 0)
    }
}

// MARK: - Decorative radar (hero background)

/// Stripped-down radar polygon used as the hero's decorative
/// background. Doesn't draw labels or grid rings — just the silhouette
/// + filled polygon, since the page already has 8 dimension cards
/// covering the same data in detail.
struct DriverDNARadarShape: View {
    let dashboard: Dashboard?
    let stroke: Color
    let fill: Color

    private var values: [Double] {
        guard let d = dashboard?.driverDNA else {
            return Array(repeating: 0, count: 8)
        }
        return [
            d.consistency, d.racecraft, d.cleanness, d.endurance,
            d.adaptability, d.improvement, d.wetWeather, d.experience,
        ]
    }

    var body: some View {
        Canvas { ctx, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2 - 4
            let count = values.count
            guard count >= 3 else { return }

            func point(_ i: Int, _ distance: CGFloat) -> CGPoint {
                let angle = CGFloat(i) / CGFloat(count) * 2 * .pi - .pi / 2
                return CGPoint(x: center.x + cos(angle) * distance,
                               y: center.y + sin(angle) * distance)
            }

            // Faint outer ring + spokes
            for ring in [0.5, 1.0] {
                var p = Path()
                for i in 0..<count {
                    let pt = point(i, radius * CGFloat(ring))
                    if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
                }
                p.closeSubpath()
                ctx.stroke(p, with: .color(Palette.borderSubtle.opacity(0.4)), lineWidth: 0.5)
            }

            var data = Path()
            for i in 0..<count {
                let v = max(0, min(values[i], 100))
                let pt = point(i, radius * CGFloat(v / 100.0))
                if i == 0 { data.move(to: pt) } else { data.addLine(to: pt) }
            }
            data.closeSubpath()
            ctx.fill(data, with: .color(fill))
            ctx.stroke(data, with: .color(stroke), lineWidth: 1.2)
        }
    }
}
