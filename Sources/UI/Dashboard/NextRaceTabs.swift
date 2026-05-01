import SwiftUI

// MARK: - Next Race tab

/// Ranked list of `NextRaceIdea` suggestions pulled from
/// `dashboard.nextRaceIdeas`. The server returns suggestions sorted by
/// match score descending; we group them by `category` (road / formula /
/// oval / dirt_road / dirt_oval) into a 2-column layout matching the
/// web's `NextRaceIdeas` component, and let each column render its own
/// stack of `HeroRaceCard`-style entries.
struct NextRaceTabContent: View {
    let ideas: [Dashboard.NextRaceIdeaEntry]
    let lookups: Dashboard.Lookups?

    /// Display order matches the web (`CAT_ORDER`) — sports car first,
    /// then formula, oval, then the dirt categories.
    private static let categoryOrder = ["road", "formula", "oval", "dirt_road", "dirt_oval"]

    /// Hex colors keyed by category — same values the web sets on the
    /// column header bullet + bottom border.
    private static let categoryColor: [String: String] = [
        "road":       "#e53935",
        "formula":    "#00bcd4",
        "oval":       "#1e88e5",
        "dirt_road":  "#43a047",
        "dirt_oval":  "#ff9800",
    ]

    /// User-facing labels keyed by category. Matches web's `CAT_LABEL`.
    private static let categoryLabel: [String: String] = [
        "road":       "Sports Car",
        "formula":    "Formula",
        "oval":       "Oval",
        "dirt_road":  "Dirt Road",
        "dirt_oval":  "Dirt Oval",
    ]

    private var columns: [(category: String, items: [Dashboard.NextRaceIdeaEntry])] {
        var byCategory: [String: [Dashboard.NextRaceIdeaEntry]] = [:]
        for idea in ideas {
            let key = idea.category.isEmpty ? "road" : idea.category
            byCategory[key, default: []].append(idea)
        }
        return Self.categoryOrder.compactMap { cat in
            guard let items = byCategory[cat], !items.isEmpty else { return nil }
            return (cat, items)
        }
    }

    var body: some View {
        if ideas.isEmpty {
            emptyState
        } else {
            VStack(alignment: .leading, spacing: 12) {
                // Section heading — matches the web's "Next Race
                // Ideas" h2 with clock icon.
                HStack(spacing: 8) {
                    Image(systemName: "clock")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Palette.textSecondary)
                    Text("Next Race Ideas")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Palette.textSecondary)
                }

                // Web uses md:grid-cols-2 — at typical macOS window
                // widths a fixed 2-column adaptive grid reads the same.
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 14),
                        GridItem(.flexible(), spacing: 14),
                    ],
                    alignment: .leading,
                    spacing: 14
                ) {
                    ForEach(columns, id: \.category) { col in
                        NextRaceCategoryColumn(
                            categoryKey: col.category,
                            title: Self.categoryLabel[col.category] ?? col.category,
                            accentHex: Self.categoryColor[col.category] ?? "#888888",
                            items: col.items,
                            lookups: lookups
                        )
                    }
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

/// Single category column — colored bullet + label + bottom border at
/// the top, then a vertical stack of cards. Mirrors the web's
/// `CategoryColumn`.
struct NextRaceCategoryColumn: View {
    let categoryKey: String
    let title: String
    let accentHex: String
    let items: [Dashboard.NextRaceIdeaEntry]
    let lookups: Dashboard.Lookups?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color(hex: accentHex))
                    .frame(width: 10, height: 10)
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .tracking(2.0)
                    .foregroundColor(Color(hex: accentHex))
                Spacer()
            }
            .padding(.bottom, 6)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color(hex: accentHex))
                    .frame(height: 1)
            }

            ForEach(items) { idea in
                NextRaceCard(
                    idea: idea,
                    // Server-baked `trackLookupKey` is the canonical
                    // way to resolve track assets — synonym folding
                    // already happened in `getDashboardData()` via
                    // `resolveIRacingTrackId`. Falls back to the
                    // case-folded raw track name when the field is
                    // empty (legacy server response).
                    trackLookup: lookups?.trackByKey(idea.viewModel?.trackLookupKey)
                        ?? lookups?.track(for: idea.trackName),
                    carLookups: idea.carClassNames.compactMap { lookups?.car(for: $0) }
                )
            }
        }
    }
}

/// Hero-style Next Race card. Mirrors the web's `HeroRaceCard` in
/// `NextRaceIdeas.tsx`: track photo background + track silhouette
/// overlay + time/score chips + brand chips + license/official/
/// fixed/duration tags + strategy pill + commentary. All pre-formatted
/// strings (`startsInLabel`, `durationLabel`, `strategyLabel`,
/// `scoreColorHex`, `strategyColorHex`) come from the server's
/// `viewModel`; falls back to local formatters only when missing
/// (legacy server response shape).
struct NextRaceCard: View {
    let idea: Dashboard.NextRaceIdeaEntry
    let trackLookup: Dashboard.TrackLookup?
    let carLookups: [Dashboard.CarLookup]

    /// Score-tiered accent color. Prefers `viewModel.scoreColorHex`;
    /// local 4-tier threshold is fallback only.
    private var scoreTint: Color {
        if let hex = idea.viewModel?.scoreColorHex {
            return Color(hex: hex)
        }
        switch idea.score {
        case 80...:  return Palette.success
        case 60...:  return Color(hex: "#7cb342")
        case 40...:  return Color(hex: "#ffb300")
        default:     return Color(hex: "#ff7043")
        }
    }

    private var strategyColor: Color {
        if let hex = idea.viewModel?.strategyColorHex {
            return Color(hex: hex)
        }
        // Server-baked color is the canonical source; this fallback
        // only fires against the legacy response shape.
        switch idea.strategy.lowercased() {
        case "pitlane":      return Color(hex: "#e53935")
        case "conservative": return Color(hex: "#ffb300")
        case "careful":      return Color(hex: "#ff9800")
        case "form":         return Color(hex: "#43a047")
        default:             return Color(hex: "#78909c")
        }
    }

    private var strategyIcon: String {
        // SF Symbol equivalents of the lucide icons the web uses
        // (Shield / Target / AlertTriangle / Flame / Zap).
        switch idea.strategy.lowercased() {
        case "pitlane":      return "shield.fill"
        case "conservative": return "scope"
        case "careful":      return "exclamationmark.triangle.fill"
        case "form":         return "flame.fill"
        case "steady":       return "bolt.fill"
        default:             return "bolt.fill"
        }
    }

    /// Pre-baked strategy label. Server already maps the enum to
    /// "Pitlane" / "On Form" / etc.; we capitalize the raw value when
    /// the server response predates the view-model rollout.
    private var strategyLabel: String {
        if let label = idea.viewModel?.strategyLabel { return label }
        switch idea.strategy.lowercased() {
        case "pitlane":      return "Pitlane"
        case "conservative": return "Conservative"
        case "careful":      return "Careful"
        case "form":         return "On Form"
        case "steady":       return "Steady"
        default:             return idea.strategy.capitalized
        }
    }

    /// Compact countdown for the time chip — `viewModel.startsInShortLabel`
    /// when available, falling back to the raw startsAt for legacy
    /// payloads. Server emits "15m" / "2h 30m" / "Starting now" /
    /// weekday-short / "Apr 28" — all rendered verbatim.
    private var startsInShort: String {
        if let label = idea.viewModel?.startsInShortLabel { return label }
        return idea.startsAtUtc
    }

    /// Race-duration chip text from the server's pre-baked label.
    /// "20 laps" / "45 min" / nil when the schedule entry has no limit.
    private var durationLabel: String? { idea.viewModel?.durationLabel }

    /// Track display label — `viewModel.trackLabel` is the canonical
    /// form ("Sebring International Raceway — National"). Falls back
    /// to the lookup's displayName + manual config concat for legacy
    /// payloads where the server post-process hasn't filled the field.
    private var trackDisplayName: String {
        if let label = idea.viewModel?.trackLabel, !label.isEmpty {
            return label
        }
        let base = trackLookup?.displayName ?? idea.trackName
        if let cfg = idea.trackConfig, !cfg.isEmpty {
            return "\(base) — \(cfg)"
        }
        return base
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
            // Base photo — track if present, car as fallback. Web uses
            // 25% / 20% opacity respectively for the layered photo;
            // we match.
            Group {
                if let url = trackLookup?.imageUrl.flatMap(URL.init) {
                    TrackImage(url: url).opacity(0.25)
                } else if let url = carLookups.first?.imageUrl.flatMap(URL.init) {
                    TrackImage(url: url).opacity(0.20)
                } else {
                    Palette.bgElevated
                }
            }

            // Track silhouette overlay (centered)
            if let svg = trackLookup?.svgPath {
                TrackSilhouette(svgPath: svg, stroke: scoreTint.opacity(0.6), lineWidth: 1.4)
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
                        brandChip(c)
                    }
                    Spacer()
                }
            }
            .padding(10)
        }
        .frame(height: 160)
    }

    private var timeChip: some View {
        HStack(spacing: 6) {
            Image(systemName: "clock")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)
            Text(startsInShort)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(scoreTint.opacity(0.8))
        )
    }

    /// "Match XX" chip — small "Match" label + bold colored score.
    /// Mirrors the web's pill: dark translucent background, score
    /// colored by `scoreTint`, "Match" subtle white-60.
    private var scoreChip: some View {
        HStack(spacing: 6) {
            Text("Match")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color.white.opacity(0.65))
            Text("\(Int(idea.score))")
                .font(.system(size: 16, weight: .bold))
                .monospacedDigit()
                .foregroundColor(scoreTint)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.55))
                .overlay(Capsule().strokeBorder(Palette.borderSubtle, lineWidth: 1))
        )
    }

    /// Brand chip with brand-color background (matching web's chip
    /// styling). Falls back to a neutral overlay when the lookup
    /// doesn't carry a color.
    private func brandChip(_ c: Dashboard.CarLookup) -> some View {
        let tint = c.color.flatMap { Color(hex: $0) }
        return BrandLogo(lookup: c, height: 22)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill((tint ?? Color.black.opacity(0.55)).opacity(tint == nil ? 1 : 0.33))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(
                                (tint ?? Palette.borderSubtle).opacity(0.6),
                                lineWidth: 1
                            )
                    )
            )
    }

    // MARK: - Body section

    private var bodySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Track + series
            HStack(alignment: .top, spacing: 10) {
                if let logoSvg = trackLookup?.logoSvg,
                   let image = SVGRenderer.rasterize(logoSvg, maxDimension: 48) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                        .padding(.top, 1)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(trackDisplayName)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Palette.textPrimary)
                        .lineLimit(1)
                    Text(idea.seriesName)
                        .font(.system(size: 12))
                        .foregroundColor(Palette.textDim)
                        .lineLimit(1)
                }
            }

            // License + Official + Fixed + Duration tags
            HStack(spacing: 6) {
                tag(idea.license, filled: true)
                if idea.official { tag("Official", filled: true, opacity: 0.6) }
                if idea.fixed    { tag("Fixed",    filled: true, opacity: 0.6) }
                if let duration = durationLabel {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 9))
                        Text(duration)
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Palette.textDim)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .strokeBorder(Palette.borderSubtle, lineWidth: 1)
                    )
                }
                Spacer()
            }

            // Strategy pill + commentary
            HStack(alignment: .top, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: strategyIcon)
                        .font(.system(size: 11, weight: .bold))
                    Text(strategyLabel)
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(strategyColor))
                .fixedSize()

                if !idea.commentary.isEmpty {
                    Text(idea.commentary)
                        .font(.system(size: 12))
                        .foregroundColor(Palette.textMuted)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(14)
    }

    /// License / Official / Fixed style chips — filled with the
    /// score-tier accent and white text, matching the web's
    /// "background: accent, opacity 0.8/0.6" pattern.
    private func tag(_ label: String, filled: Bool, opacity: Double = 0.8) -> some View {
        Text(label)
            .font(.system(size: 11, weight: .bold))
            .tracking(0.4)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(filled ? scoreTint.opacity(opacity) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .strokeBorder(filled ? Color.clear : Palette.borderSubtle, lineWidth: 1)
                    )
            )
    }
}

// MARK: - Previous Races tab

/// Previous Races tab — renders server-baked `PreviousRaceCard`s.
/// Includes session-type tabs (Races / Practice / Time Trials) and a
/// Cards / List view toggle, matching the web's `RaceHistory`
/// component. Counts come from the cards' `viewModel.sessionTypeTab`.
struct PreviousRacesTabContent: View {
    let cards: [Dashboard.PreviousRaceCard]
    let lookups: Dashboard.Lookups?

    enum SessionTab: String, CaseIterable {
        case races, practices, timeTrials

        /// Maps to `viewModel.sessionTypeTab` strings on the wire.
        var wireKey: String {
            switch self {
            case .races:       return "races"
            case .practices:   return "practices"
            case .timeTrials:  return "time_trials"
            }
        }

        var label: String {
            switch self {
            case .races:       return "Races"
            case .practices:   return "Practice"
            case .timeTrials:  return "Time Trials"
            }
        }

        var icon: String {
            switch self {
            case .races:       return "flag"
            case .practices:   return "cone"
            case .timeTrials:  return "timer"
            }
        }
    }

    enum ViewMode: String, CaseIterable {
        case cards, list

        var label: String {
            switch self {
            case .cards: return "Cards"
            case .list:  return "List"
            }
        }
        var icon: String {
            switch self {
            case .cards: return "square.grid.2x2"
            case .list:  return "list.bullet"
            }
        }
    }

    @State private var activeTab: SessionTab = .races
    @State private var mode: ViewMode = .cards

    private var grouped: [SessionTab: [Dashboard.PreviousRaceCard]] {
        var out: [SessionTab: [Dashboard.PreviousRaceCard]] = [.races: [], .practices: [], .timeTrials: []]
        for card in cards {
            switch card.viewModel.sessionTypeTab {
            case "practices":   out[.practices, default: []].append(card)
            case "time_trials": out[.timeTrials, default: []].append(card)
            default:            out[.races, default: []].append(card)
            }
        }
        return out
    }

    private var activeCards: [Dashboard.PreviousRaceCard] {
        grouped[activeTab] ?? []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            controlsRow

            if cards.isEmpty {
                emptyAllState
            } else if activeCards.isEmpty {
                emptyTabState
            } else {
                contentForMode
            }
        }
    }

    // MARK: - Controls

    private var controlsRow: some View {
        HStack(spacing: 10) {
            // Session-type segmented control
            HStack(spacing: 0) {
                ForEach(SessionTab.allCases, id: \.self) { tab in
                    let isActive = tab == activeTab
                    let count = (grouped[tab] ?? []).count
                    Button {
                        activeTab = tab
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 11))
                            Text(tab.label.uppercased())
                                .font(.system(size: 10, weight: .semibold))
                                .tracking(0.6)
                            if count > 0 {
                                Text("\(count)")
                                    .font(.system(size: 10, weight: .semibold))
                                    .monospacedDigit()
                                    .foregroundColor(isActive ? Palette.textSecondary : Palette.textMuted)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .foregroundColor(isActive ? Palette.textPrimary : Palette.textDim)
                        .background(isActive ? Color.white.opacity(0.10) : Color.clear)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Palette.borderSubtle, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            Spacer()

            // View-mode segmented control
            HStack(spacing: 0) {
                ForEach(ViewMode.allCases, id: \.self) { m in
                    let isActive = m == mode
                    Button {
                        mode = m
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: m.icon)
                                .font(.system(size: 11))
                            Text(m.label.uppercased())
                                .font(.system(size: 10, weight: .semibold))
                                .tracking(0.6)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .foregroundColor(isActive ? Palette.textPrimary : Palette.textDim)
                        .background(isActive ? Color.white.opacity(0.10) : Color.clear)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Palette.borderSubtle, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var contentForMode: some View {
        switch mode {
        case .cards:
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 14),
                    GridItem(.flexible(), spacing: 14),
                ],
                alignment: .leading,
                spacing: 14
            ) {
                ForEach(activeCards) { card in
                    PreviousRaceCardView(card: card, lookups: lookups)
                }
            }
        case .list:
            VStack(spacing: 0) {
                ForEach(Array(activeCards.enumerated()), id: \.element.id) { idx, card in
                    PreviousRaceListRow(card: card, lookups: lookups)
                    if idx != activeCards.count - 1 {
                        Divider().overlay(Palette.borderSubtle)
                    }
                }
            }
            .panel(padding: 0)
        }
    }

    // MARK: - Empty states

    private var emptyAllState: some View {
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
    }

    private var emptyTabState: some View {
        let kind: String = {
            switch activeTab {
            case .races:       return "races"
            case .practices:   return "practices"
            case .timeTrials:  return "time trials"
            }
        }()
        return VStack(spacing: 8) {
            Image(systemName: activeTab.icon)
                .font(.system(size: 24))
                .foregroundColor(Palette.textMuted)
            Text("No \(kind) recorded yet")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Palette.textDim)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .panel()
    }
}

// MARK: - Previous Race card (web `RaceCard` parity)

/// Card-style Previous Races entry. Renders the server's `viewModel`
/// verbatim — no client-side formatting. Matches the web's
/// `RaceCard.tsx` layout: 160-tall hero header with track image +
/// SVG silhouette + game/brand chips, then a body with track + car
/// + giant position badge + optional practice/qualifying chips +
/// footer (date · session label · best lap).
struct PreviousRaceCardView: View {
    let card: Dashboard.PreviousRaceCard
    let lookups: Dashboard.Lookups?

    private var session: Dashboard.PreviousRaceSession { card.session }
    private var vm: Dashboard.PreviousRaceViewModel { card.viewModel }
    private var trackLookup: Dashboard.TrackLookup? {
        // Prefer the server-baked `trackLookupKey` (synonym-folded by
        // `getDashboardData()` post-processing). Falls back to the
        // legacy raw-name lookup for older server responses.
        lookups?.trackByKey(vm.trackLookupKey) ?? lookups?.track(for: session.trackName)
    }
    private var carLookup: Dashboard.CarLookup?     { lookups?.car(for: session.carModel) }

    private var positionColor: Color {
        if let hex = vm.positionColorHex { return Color(hex: hex) }
        return Palette.textDim
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

    // MARK: Hero

    private var heroHeader: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let url = trackLookup?.imageUrl.flatMap(URL.init) {
                    TrackImage(url: url).opacity(0.25)
                } else if let url = carLookup?.imageUrl.flatMap(URL.init) {
                    TrackImage(url: url).opacity(0.20)
                } else {
                    Palette.bgElevated
                }
            }

            if let svg = trackLookup?.svgPath {
                TrackSilhouette(svgPath: svg, stroke: Palette.brand.opacity(0.55), lineWidth: 1.4)
                    .padding(20)
            }

            LinearGradient(
                colors: [.clear, Color.black.opacity(0.55)],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)

            // Game label chip — top-left
            VStack {
                HStack {
                    gameChip
                    Spacer()
                }
                Spacer()
                HStack {
                    if let car = carLookup {
                        brandChip(car)
                    }
                    Spacer()
                }
            }
            .padding(10)
        }
        .frame(height: 140)
    }

    private var gameChip: some View {
        Text(vm.gameLabel)
            .font(.system(size: 10, weight: .semibold))
            .tracking(0.5)
            .foregroundColor(Color.white.opacity(0.85))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.55))
                    .overlay(
                        Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                    )
            )
    }

    private func brandChip(_ c: Dashboard.CarLookup) -> some View {
        let tint = c.color.flatMap { Color(hex: $0) }
        return BrandLogo(lookup: c, height: 28)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill((tint ?? Color.black.opacity(0.55)).opacity(tint == nil ? 1 : 0.33))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(
                                (tint ?? Palette.borderSubtle).opacity(0.6),
                                lineWidth: 1
                            )
                    )
            )
    }

    // MARK: Body

    private var bodySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        if let svg = trackLookup?.logoSvg,
                           let img = SVGRenderer.rasterize(svg, maxDimension: 36) {
                            Image(nsImage: img)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 16, height: 16)
                        }
                        Text(trackLookup?.displayName ?? vm.trackLabel)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Palette.textPrimary)
                            .lineLimit(1)
                    }
                    Text(session.carModel)
                        .font(.system(size: 11))
                        .foregroundColor(Palette.textDim)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                positionBadge
            }

            if card.practiceSession != nil || card.qualifyingSession != nil {
                preRaceChips
            }

            footer
        }
        .padding(14)
    }

    @ViewBuilder
    private var positionBadge: some View {
        if let display = vm.positionDisplay {
            VStack(alignment: .trailing, spacing: 0) {
                if display.hasPrefix("P") {
                    HStack(alignment: .lastTextBaseline, spacing: 1) {
                        Text("P")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(positionColor.opacity(0.7))
                        Text(String(display.dropFirst()))
                            .font(.system(size: 36, weight: .black, design: .rounded))
                            .monospacedDigit()
                            .foregroundColor(positionColor)
                    }
                } else {
                    // DNF / TT / —
                    Text(display)
                        .font(.system(size: 22, weight: .black))
                        .foregroundColor(positionColor)
                }
                if let fs = vm.fieldSizeLabel {
                    Text(fs)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(positionColor.opacity(0.6))
                }
            }
        }
    }

    @ViewBuilder
    private var preRaceChips: some View {
        VStack(spacing: 6) {
            if let label = vm.practiceBestLapLabel {
                preRaceRow(
                    title: "PRACTICE",
                    primary: label,
                    secondary: nil,
                    tint: Palette.borderSubtle,
                    note: vm.practiceIncidentsLabel
                )
            }
            if let lap = vm.qualifyingBestLapLabel {
                preRaceRow(
                    title: "QUALIFYING",
                    primary: lap,
                    secondary: vm.qualifyingPositionLabel,
                    tint: Color(hex: "#F5CA47").opacity(0.25),
                    note: nil
                )
            }
        }
    }

    private func preRaceRow(title: String, primary: String, secondary: String?, tint: Color, note: String?) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(title)
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.6)
                    .foregroundColor(Palette.textMuted)
                Spacer()
                HStack(spacing: 6) {
                    if let secondary {
                        Text(secondary)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color(hex: "#F5CA47"))
                    }
                    Text(primary)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Palette.textDim)
                }
            }
            if let note {
                Text(note)
                    .font(.system(size: 10))
                    .foregroundColor(Palette.textMuted)
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(tint, lineWidth: 1)
        )
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                HStack(spacing: 4) {
                    Text(vm.dateLabel)
                        .font(.system(size: 10))
                        .foregroundColor(Palette.textMuted)
                    Text("·")
                        .font(.system(size: 10))
                        .foregroundColor(Palette.textMuted.opacity(0.5))
                    Text(vm.sessionLabel)
                        .font(.system(size: 10))
                        .foregroundColor(Palette.textMuted.opacity(0.7))
                }
                Spacer()
                if vm.bestLapLabel != "—" {
                    Text(vm.bestLapLabel)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Palette.textDim)
                }
            }
            if let inc = vm.incidentsLabel {
                Text(inc)
                    .font(.system(size: 10))
                    .foregroundColor(Palette.textMuted)
            }
        }
    }
}

// MARK: - Previous Race list row (compact List view)

/// Compact list row used by the Previous Races tab's "List" view.
/// Mirrors the web's `RaceListView` layout — single row per session
/// with position / track + car / date + best lap.
struct PreviousRaceListRow: View {
    let card: Dashboard.PreviousRaceCard
    let lookups: Dashboard.Lookups?

    private var vm: Dashboard.PreviousRaceViewModel { card.viewModel }
    private var session: Dashboard.PreviousRaceSession { card.session }
    private var trackLookup: Dashboard.TrackLookup? {
        // Prefer the server-baked `trackLookupKey` (synonym-folded by
        // `getDashboardData()` post-processing). Falls back to the
        // legacy raw-name lookup for older server responses.
        lookups?.trackByKey(vm.trackLookupKey) ?? lookups?.track(for: session.trackName)
    }
    private var positionColor: Color {
        if let hex = vm.positionColorHex { return Color(hex: hex) }
        return Palette.textDim
    }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(spacing: 0) {
                Text(vm.positionDisplay ?? "—")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(positionColor)
            }
            .frame(width: 56, alignment: .center)

            VStack(alignment: .leading, spacing: 2) {
                Text(trackLookup?.displayName ?? vm.trackLabel)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Palette.textPrimary)
                    .lineLimit(1)
                Text(session.carModel)
                    .font(.system(size: 11))
                    .foregroundColor(Palette.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(vm.dateLabel)
                    .font(.system(size: 10))
                    .foregroundColor(Palette.textDim)
                if vm.bestLapLabel != "—" {
                    Text(vm.bestLapLabel)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(Palette.textMuted)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}
