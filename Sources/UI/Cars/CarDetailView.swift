import SwiftUI

/// Typed route wrapper used to push a car-detail destination onto
/// `CarsView`'s NavigationStack. The route is keyed on `brandKey`
/// (e.g. "bmw") rather than the raw manufacturer label so the
/// CarAffinityCard's `affinity.brandKey` round-trips cleanly.
struct CarDetailRoute: Hashable {
    let brandKey: String
}

/// Brand detail page — drilled into when a `CarAffinityCard` is
/// tapped. Mirrors what the web's `/drive/car/[name]` route surfaces
/// using only data already on the dashboard payload:
///
///   - Brand visuals (logo / color / image)  → `lookups.cars`
///   - Affinity (score / trend)              → `topCars[]` filtered
///                                              by `brandKey`
///   - Aggregate stats + recent sessions     → `previousRaces[]`
///                                              filtered by carModel
///
/// Items deferred to a follow-up server PR (need a per-car detail
/// endpoint): per-car iRating chart, performance-per-track breakdown,
/// and a server-baked narrative summary.
struct CarDetailView: View {
    let brandKey: String

    @ObservedObject private var poller: DashboardPoller

    @MainActor
    init(brandKey: String) {
        self.brandKey = brandKey
        self.poller = .shared
    }

    private var dashboard: Dashboard? { poller.latest }
    private var lookups: Dashboard.Lookups? { dashboard?.lookups }

    private var affinity: Dashboard.CarAffinityEntry? {
        dashboard?.topCars?.first { $0.brandKey.caseInsensitiveCompare(brandKey) == .orderedSame }
    }

    /// Brand visuals — try to pick the lookup entry whose `brandKey`
    /// matches; fall back to the first car class assigned to this
    /// affinity.
    private var brandLookup: Dashboard.CarLookup? {
        if let direct = lookups?.cars.first(where: { ($0.brandKey ?? "").caseInsensitiveCompare(brandKey) == .orderedSame }) {
            return direct
        }
        if let firstCar = affinity?.cars?.first?.carModel {
            return lookups?.car(for: firstCar)
        }
        return nil
    }

    /// All Previous Races on any of this brand's car models. The
    /// dashboard's `previousRaces` already carries `carModel`, so we
    /// just match by membership in the affinity's car-model set.
    private var carSessions: [Dashboard.PreviousRaceCard] {
        let cards = dashboard?.previousRaces ?? []
        let modelSet = Set((affinity?.cars ?? []).map { $0.carModel.lowercased() })
        // Fall back to substring-on-brandKey when no direct car list
        // exists — matches the dashboard sidebar's car affinity build
        // path.
        return cards.filter { card in
            let model = card.session.carModel.lowercased()
            if !modelSet.isEmpty { return modelSet.contains(model) }
            return model.contains(brandKey.lowercased())
        }
    }

    private var brandColor: Color? {
        brandLookup?.color.flatMap { Color(hex: $0) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                hero
                statsRow
                    .padding(.horizontal, 24)
                if let cars = affinity?.cars, !cars.isEmpty {
                    carBreakdownSection(cars)
                        .padding(.horizontal, 24)
                }
                if !lapTimeSeries.isEmpty {
                    lapTimeChart
                        .padding(.horizontal, 24)
                }
                if !carSessions.isEmpty {
                    sessionsList
                        .padding(.horizontal, 24)
                }
                Spacer(minLength: 30)
            }
        }
        .navigationTitle(affinity?.manufacturer ?? brandKey.capitalized)
    }

    // MARK: - Hero

    @ViewBuilder
    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            // Background photo (faint) — first car class with an
            // image wins.
            Group {
                if let url = brandLookup?.imageUrl.flatMap(URL.init) {
                    TrackImage(url: url).opacity(0.30)
                } else {
                    Palette.bgElevated
                }
            }

            // Brand color tint overlay.
            (brandColor ?? Color.clear).opacity(0.15)

            // Bottom gradient for legibility.
            LinearGradient(
                colors: [.clear, Color.black.opacity(0.6)],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)

            HStack(alignment: .bottom, spacing: 18) {
                if let lookup = brandLookup, lookup.logoSvg != nil || lookup.logoPng != nil {
                    BrandLogo(lookup: lookup, height: 64)
                        .padding(.trailing, 4)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(affinity?.manufacturer ?? brandKey.capitalized)
                        .font(.system(size: 26, weight: .heavy))
                        .foregroundColor(Palette.textPrimary)
                        .lineLimit(2)
                    Text("\(carSessions.count) race\(carSessions.count == 1 ? "" : "s") in this brand")
                        .font(.system(size: 12))
                        .foregroundColor(Palette.textDim)
                }
                Spacer(minLength: 8)
                if let affinity {
                    affinityBadge(affinity)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 30)
            .padding(.bottom, 22)
        }
        .frame(height: 240)
    }

    private func affinityBadge(_ affinity: Dashboard.CarAffinityEntry) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text("AFFINITY")
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.4)
                .foregroundColor(Palette.textMuted)
            Text("\(Int(affinity.affinityScore.rounded()))")
                .font(.system(size: 28, weight: .black))
                .monospacedDigit()
                .foregroundColor(brandColor ?? Palette.textPrimary)
            Text(trendLabel(affinity.trend))
                .font(.system(size: 10))
                .foregroundColor(Palette.textDim)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.black.opacity(0.55))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder((brandColor ?? Palette.borderSubtle).opacity(0.35), lineWidth: 1)
                )
        )
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

    /// 6-up aggregate stats row. Same shape as the Track Detail row
    /// so the two pages read as siblings — Races / Wins / Podiums /
    /// Clean / Best / Avg-Inc.
    private var statsRow: some View {
        HStack(spacing: 0) {
            statCol("Races", value: "\(carSessions.count)")
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
        carSessions.filter { $0.session.finishPosition == 1 }.count
    }

    private var podiumCount: Int {
        carSessions.filter {
            guard let p = $0.session.finishPosition else { return false }
            return p >= 1 && p <= 3
        }.count
    }

    private var cleanRaceCount: Int {
        carSessions.filter { ($0.session.incidentCount ?? 0) == 0 }.count
    }

    private var bestPosition: Int? {
        carSessions.compactMap { $0.session.finishPosition }
            .filter { $0 > 0 }
            .min()
    }

    private var avgIncidents: Double {
        guard !carSessions.isEmpty else { return 0 }
        let total = carSessions.reduce(0) { $0 + ($1.session.incidentCount ?? 0) }
        return Double(total) / Double(carSessions.count)
    }

    // MARK: - Car breakdown

    /// Per-car-model breakdown rows. Same compact layout as the
    /// expanded "cars" section on the parent affinity card; here it's
    /// always shown and gets a bit more breathing room.
    private func carBreakdownSection(_ cars: [Dashboard.CarAffinityEntry.CarEntry]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "car.2.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Palette.textSecondary)
                Text("Car Models")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Palette.textSecondary)
            }
            VStack(spacing: 6) {
                ForEach(cars, id: \.carModel) { car in
                    HStack {
                        Text(car.carModel)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Palette.textSecondary)
                            .lineLimit(1)
                        Spacer(minLength: 6)
                        Text("\(car.sessionCount) race\(car.sessionCount == 1 ? "" : "s")")
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

    private var lapTimeSeries: [Double] {
        let isoFmt = ISO8601DateFormatter()
        isoFmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return carSessions.compactMap { card -> (Date, Double)? in
            guard let lap = card.session.bestLapTime, lap > 0 else { return nil }
            let date = isoFmt.date(from: card.session.createdAt)
                ?? ISO8601DateFormatter().date(from: card.session.createdAt)
            guard let date else { return nil }
            return (date, lap)
        }
        .sorted { $0.0 < $1.0 }
        .map(\.1)
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
                if let best = lapTimeSeries.min() {
                    Text("Best: \(formatLap(best))")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(brandColor ?? Palette.brand)
                }
            }
            // Note: car best-lap times are NOT comparable across
            // tracks — a 1:23 at Sebring vs 2:48 at Spa is a
            // different car at a different circuit. The sparkline
            // here shows the user's recency-ordered best laps and
            // highlights the absolute fastest, but it's not a
            // "getting faster" indicator. Track Detail's chart is
            // more meaningful for that.
            LapTimeSparkline(points: lapTimeSeries)
                .frame(height: 80)
            Text("Mixed-circuit lap times — see Track pages for per-track progression.")
                .font(.system(size: 10))
                .foregroundColor(Palette.textMuted)
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
                Text("Races in this Brand")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Palette.textSecondary)
            }
            VStack(spacing: 0) {
                ForEach(Array(carSessions.enumerated()), id: \.element.id) { idx, card in
                    PreviousRaceListRow(card: card, lookups: lookups)
                    if idx != carSessions.count - 1 {
                        Divider().overlay(Palette.borderSubtle)
                    }
                }
            }
            .panel(padding: 0)
        }
    }
}
