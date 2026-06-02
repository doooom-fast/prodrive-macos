import SwiftUI

/// Full Cars destination — mirrors the web's `CarAffinityPage.tsx`.
/// Hero band with title + stats + scroll-anchor brand chips, then a
/// 2-column grid of `CarAffinityCard`s rendered straight from
/// `dashboard.topCars`.
///
/// Same data caveat as Tracks: `dashboard.topCars` is server-capped
/// at 10 entries (intended for the dashboard sidebar). Web shows the
/// full list. Tracked as a follow-up — server needs either a higher
/// cap on `topCars` or a separate `allCars` field. Today's view
/// shows up to 10, which is more than the placeholder it replaces.
struct CarsView: View {
    @ObservedObject private var poller: DashboardPoller

    @MainActor
    init() { self.poller = .shared }

    private var dashboard: Dashboard? { poller.latest }
    private var cars: [Dashboard.CarAffinityEntry] { dashboard?.topCars ?? [] }
    private var lookups: Dashboard.Lookups? { dashboard?.lookups }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    hero
                    if cars.isEmpty {
                        emptyCard
                            .padding(.horizontal, 24)
                            .padding(.top, 16)
                    } else {
                        carGrid
                            .padding(.horizontal, 24)
                            .padding(.top, 16)
                            .padding(.bottom, 30)
                    }
                }
            }
            .navigationDestination(for: CarDetailRoute.self) { route in
                CarDetailView(brandKey: route.brandKey)
            }
        }
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Car Affinity")
                .font(.system(size: 30, weight: .heavy))
                .foregroundColor(Palette.textPrimary)
            Text("Discover which machinery suits your driving style")
                .font(.system(size: 13))
                .foregroundColor(Palette.textDim)
                .frame(maxWidth: 420, alignment: .leading)

            HStack(spacing: 28) {
                statColumn(value: "\(dashboard?.stats.uniqueCars ?? 0)", label: "Cars")
                statColumn(value: "\(dashboard?.stats.totalRaces ?? 0)", label: "Sessions")
            }
            .padding(.top, 14)

            // Brand chips — quick-glance ranking. The web uses these
            // as anchor links to scroll to the matching card; native
            // doesn't support intra-page anchors yet, so they're
            // purely informational here.
            if !cars.isEmpty {
                FlowingBrandChips(cars: cars, lookups: lookups)
                    .padding(.top, 14)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 30)
        .padding(.bottom, 28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.bgPanel.opacity(0.5))
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

    private var carGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 14),
                GridItem(.flexible(), spacing: 14),
            ],
            alignment: .leading,
            spacing: 14
        ) {
            ForEach(cars) { affinity in
                CarAffinityCard(
                    affinity: affinity,
                    lookup: lookups?.car(for: affinity.cars?.first?.carModel ?? affinity.manufacturer)
                )
            }
        }
    }

    // MARK: - Empty card

    private var emptyCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "car.fill")
                .font(.system(size: 32))
                .foregroundColor(Palette.brand.opacity(0.6))
            Text("Your car affinity develops as you race different machinery")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Palette.textPrimary)
                .multilineTextAlignment(.center)
            Text("Each car class you race adds to your affinity profile.")
                .font(.system(size: 12))
                .foregroundColor(Palette.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 50)
        .panel()
    }
}

// MARK: - Brand chips row

/// Wrapping row of brand chips. Each chip = brand logo + manufacturer
/// name + session-count pill. Tinted with the brand's accent color
/// when one is available in the lookup.
struct FlowingBrandChips: View {
    let cars: [Dashboard.CarAffinityEntry]
    let lookups: Dashboard.Lookups?

    var body: some View {
        // Wrap-flowing rows are awkward in plain SwiftUI; LazyVGrid
        // with adaptive minimum width approximates the web's
        // flex-wrap behavior at native window widths.
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 120, maximum: 220), spacing: 6, alignment: .leading)],
            alignment: .leading,
            spacing: 6
        ) {
            ForEach(cars) { car in
                chip(for: car)
            }
        }
    }

    private func chip(for car: Dashboard.CarAffinityEntry) -> some View {
        let lookup = lookups?.car(for: car.cars?.first?.carModel ?? car.manufacturer)
        let tint = lookup?.color.flatMap { Color(hex: $0) }

        return HStack(spacing: 6) {
            if let lookup, lookup.logoSvg != nil || lookup.logoPng != nil {
                BrandLogo(lookup: lookup, height: 14)
            }
            Text(car.manufacturer)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(tint ?? Palette.textSecondary)
                .lineLimit(1)
            Spacer(minLength: 4)
            Text("\(car.totalSessions)")
                .font(.system(size: 10))
                .monospacedDigit()
                .foregroundColor((tint ?? Palette.textMuted).opacity(0.7))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill((tint ?? Color.white.opacity(0.06)).opacity(tint == nil ? 1 : 0.10))
                .overlay(
                    Capsule().strokeBorder(
                        (tint ?? Palette.borderSubtle).opacity(0.40),
                        lineWidth: 1
                    )
                )
        )
    }
}

// MARK: - Affinity card

/// One brand affinity card — same shape as the web's
/// `CarAffinityCard`: header (logo + manufacturer + sessions/avgPos
/// summary | affinity score + trend), gradient progress bar tinted
/// by brand color, 3-col stat row (Best | Incidents | Laps), and
/// expandable car list at the bottom.
struct CarAffinityCard: View {
    let affinity: Dashboard.CarAffinityEntry
    /// Brand lookup — resolves brand logo + color via the dashboard
    /// lookups bundle. Optional because the lookup table only carries
    /// entries for cars referenced by other dashboard surfaces.
    let lookup: Dashboard.CarLookup?

    private var brandColor: Color? {
        lookup?.color.flatMap { Color(hex: $0) }
    }

    var body: some View {
        // Whole card is a NavigationLink to the per-brand detail
        // page. The previous expand/collapse on the inline car list
        // is gone — the detail page surfaces everything, so the card
        // doesn't need a competing interactive control inside its
        // tap target.
        NavigationLink(value: CarDetailRoute(brandKey: affinity.brandKey)) {
            VStack(alignment: .leading, spacing: 14) {
                header
                progressBar
                statsRow
                if let cars = affinity.cars, !cars.isEmpty {
                    inlineCarList(cars)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Palette.bgElevated)
                    .overlay(
                        // Brand-tinted overlay — mirrors the web's
                        // `${brandColor}14` background hex tint.
                        (brandColor ?? Color.clear).opacity(0.08)
                    )
            )
            .overlay(
                // Left brand-color stripe — same accent the web shows.
                HStack {
                    Rectangle()
                        .fill(brandColor ?? Palette.borderSubtle)
                        .frame(width: 3)
                    Spacer()
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Palette.borderSubtle, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            HStack(spacing: 10) {
                if let lookup, lookup.logoSvg != nil || lookup.logoPng != nil {
                    BrandLogo(lookup: lookup, height: 26)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(affinity.manufacturer)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Palette.textSecondary)
                    HStack(spacing: 6) {
                        Text("\(affinity.totalSessions) sessions")
                            .font(.system(size: 11))
                            .foregroundColor(Palette.textSecondary)
                        Text("·")
                            .foregroundColor(Palette.textDim)
                        if let avg = affinity.avgPosition {
                            Text("P\(String(format: "%.1f", avg)) avg")
                                .font(.system(size: 11))
                                .foregroundColor(Palette.textSecondary)
                        } else {
                            Text("— avg")
                                .font(.system(size: 11))
                                .foregroundColor(Palette.textDim)
                        }
                    }
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 4) {
                Text("AFFINITY")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1.4)
                    .foregroundColor(Palette.textMuted)
                Text("\(Int(affinity.affinityScore.rounded()))")
                    .font(.system(size: 22, weight: .bold))
                    .monospacedDigit()
                    .foregroundColor(Palette.textPrimary)
                trendChip
            }
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
        switch affinity.trend {
        case "improving": return "arrow.up.right"
        case "declining": return "arrow.down.right"
        case "new":       return "circle.fill"
        default:          return "arrow.right"
        }
    }

    private var trendLabel: String {
        switch affinity.trend {
        case "improving": return "Improving"
        case "declining": return "Declining"
        case "new":       return "New"
        default:          return "Stable"
        }
    }

    // MARK: Progress bar

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 5)
                Capsule()
                    .fill(brandColor ?? Palette.textSecondary)
                    .frame(
                        width: max(0, geo.size.width * CGFloat(min(max(affinity.affinityScore, 0), 100) / 100.0)),
                        height: 5
                    )
            }
        }
        .frame(height: 5)
    }

    // MARK: Stats row

    private var statsRow: some View {
        HStack(spacing: 0) {
            statColumn("Best", value: affinity.bestPosition.map { "P\($0)" } ?? "—")
            divider
            statColumn("Incidents", value: String(format: "%.1f", affinity.avgIncidents))
            divider
            statColumn("Laps", value: "\(affinity.totalLaps)")
        }
        .padding(.vertical, 8)
        .overlay(Rectangle().fill(Palette.borderSubtle).frame(height: 1), alignment: .top)
        .overlay(Rectangle().fill(Palette.borderSubtle).frame(height: 1), alignment: .bottom)
    }

    private func statColumn(_ label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.0)
                .foregroundColor(Palette.textMuted)
            Text(value)
                .font(.system(size: 13, weight: .bold))
                .monospacedDigit()
                .foregroundColor(Palette.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Rectangle()
            .fill(Palette.borderSubtle)
            .frame(width: 1, height: 28)
    }

    // MARK: Inline car list

    /// Always-shown car list — replaces the previous expand/collapse
    /// button so the whole card can be a single NavigationLink. The
    /// detail page surfaces the same data with more breathing room,
    /// so a competing toggle inside the card's tap target was the
    /// wrong affordance.
    @ViewBuilder
    private func inlineCarList(_ cars: [Dashboard.CarAffinityEntry.CarEntry]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(cars.count) car\(cars.count == 1 ? "" : "s")")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Palette.textDim)
            VStack(spacing: 4) {
                ForEach(cars, id: \.carModel) { car in
                    HStack {
                        Text(car.carModel)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Palette.textSecondary)
                            .lineLimit(1)
                        Spacer(minLength: 6)
                        Text("\(car.sessionCount) session\(car.sessionCount == 1 ? "" : "s")")
                            .font(.system(size: 10))
                            .foregroundColor(Palette.textDim)
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
    }
}
