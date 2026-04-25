import SwiftUI

/// Lucide-matching icon set. The web uses `lucide-react` for nav
/// glyphs; these SwiftUI renderings match those icons stroke-for-
/// stroke so the native apps feel like the same product, not a
/// cousin built on SF Symbols.
///
/// Each icon is rendered as a `Path` stroke inside a 24×24 viewBox
/// (the lucide default) scaled to whatever size the caller asks for.
/// Stroke width is `2 / 24 * size` so the icon weight scales
/// proportionally — matching lucide's `stroke-width="2"` at native
/// 24pt.
///
/// To add an icon: fetch the raw SVG from
/// https://lucide.dev/icons/<name>, translate each `<path d=…>` /
/// `<circle>` / `<rect>` into its Swift `Path` equivalent below, and
/// register it in the `name` switch. Keep the stroke
/// `lineCap: .round, lineJoin: .round` settings — those match the
/// web rendering exactly.
enum LucideIcon: String {
    case dashboard = "layout-dashboard"
    case dna = "dna"
    case when = "calendar-clock"
    case tracks = "map-pin"
    case cars = "car"
    case moments = "sparkles"
    case races = "flag"
    case profile = "user"
}

struct LucideIconView: View {
    let icon: LucideIcon
    var size: CGFloat = 24
    var color: Color = .primary
    var lineWidth: CGFloat? = nil

    private var effectiveLineWidth: CGFloat {
        // lucide's native stroke-width is 2 at 24pt viewBox — scale
        // proportionally so a 36pt glyph reads with the same visual
        // weight it does at 24pt on the web.
        lineWidth ?? (2.0 / 24.0 * size)
    }

    var body: some View {
        Canvas { ctx, _ in
            let stroke = StrokeStyle(
                lineWidth: effectiveLineWidth,
                lineCap: .round,
                lineJoin: .round
            )
            let path = Self.path(for: icon, size: size)
            ctx.stroke(path, with: .color(color), style: stroke)
        }
        .frame(width: size, height: size)
        .accessibilityLabel(icon.rawValue.replacingOccurrences(of: "-", with: " "))
    }

    /// Build the composed `Path` for a given icon at `size` (scaled from
    /// the 24-unit lucide viewBox). Each case mirrors the primitives in
    /// the upstream SVG one-to-one.
    static func path(for icon: LucideIcon, size: CGFloat) -> Path {
        let s = size / 24.0
        var p = Path()

        switch icon {
        case .dashboard:
            // Four rounded rectangles, rx=1.
            for rect in [
                CGRect(x: 3, y: 3,  width: 7, height: 9),
                CGRect(x: 14, y: 3, width: 7, height: 5),
                CGRect(x: 14, y: 12, width: 7, height: 9),
                CGRect(x: 3, y: 16, width: 7, height: 5),
            ] {
                p.addRoundedRect(
                    in: rect.scaled(by: s),
                    cornerSize: CGSize(width: 1 * s, height: 1 * s))
            }

        case .dna:
            // Top ladder rung set — short diagonals at different heights.
            p.line(from: .init(x: 10, y: 16), to: .init(x: 11.5, y: 17.5), s: s)
            p.line(from: .init(x: 14, y: 8),  to: .init(x: 12.5, y: 6.5),  s: s)
            // Upper helical curve.
            p.cubicRel(
                from: .init(x: 15, y: 2),
                c1: .init(x: -1.798, y: 1.998),
                c2: .init(x: -2.518, y: 3.995),
                to: .init(x: -2.807, y: 5.993),
                s: s)
            p.line(from: .init(x: 16.5, y: 10.5), to: .init(x: 17.5, y: 11.5), s: s)
            p.line(from: .init(x: 17, y: 6),      to: .init(x: 14.109, y: 3.109), s: s)
            // Middle S-curve spanning the full width.
            p.cubicRel(
                from: .init(x: 2, y: 15),
                c1: .init(x: 6.667, y: -6),
                c2: .init(x: 13.333, y: 0),
                to: .init(x: 20, y: -6),
                s: s)
            p.line(from: .init(x: 20, y: 9),        to: .init(x: 20.891, y: 9.891),  s: s)
            p.line(from: .init(x: 3.109, y: 14.109),to: .init(x: 4, y: 15),           s: s)
            p.line(from: .init(x: 6.5, y: 12.5),    to: .init(x: 7.5, y: 13.5),       s: s)
            p.line(from: .init(x: 7, y: 18),        to: .init(x: 9.891, y: 20.891),   s: s)
            // Lower helical curve.
            p.cubicRel(
                from: .init(x: 9, y: 22),
                c1: .init(x: 1.798, y: -1.998),
                c2: .init(x: 2.518, y: -3.995),
                to: .init(x: 2.807, y: -5.993),
                s: s)

        case .when:
            // Clock hands inside the bubble.
            p.line(from: .init(x: 16, y: 14),   to: .init(x: 16, y: 16.2),   s: s)
            p.line(from: .init(x: 16, y: 16.2), to: .init(x: 17.6, y: 17.2), s: s)
            // Top tick marks of the calendar (vertical strokes above the box).
            p.line(from: .init(x: 16, y: 2), to: .init(x: 16, y: 6), s: s)
            p.line(from: .init(x: 8, y: 2),  to: .init(x: 8, y: 6),  s: s)
            // Calendar body — partial rect opened on the right so the
            // clock can overlap. Drawn as a single multi-segment path
            // following the lucide source literally.
            p.move(to: .init(x: 21 * s, y: 7.5 * s))
            p.line(to: .init(x: 21 * s, y: 6 * s))
            p.arcRel(
                from: .init(x: 21, y: 6),
                radius: 2,
                largeArc: false,
                sweep: false,
                delta: .init(x: -2, y: -2),
                s: s)
            p.line(to: .init(x: 5 * s, y: 4 * s))
            p.arcRel(
                from: .init(x: 5, y: 4),
                radius: 2,
                largeArc: false,
                sweep: false,
                delta: .init(x: -2, y: 2),
                s: s)
            p.line(to: .init(x: 3 * s, y: 20 * s))
            p.arcRel(
                from: .init(x: 3, y: 20),
                radius: 2,
                largeArc: false,
                sweep: false,
                delta: .init(x: 2, y: 2),
                s: s)
            p.line(to: .init(x: 8.5 * s, y: 22 * s))
            // Horizontal divider below the calendar title.
            p.move(to: .init(x: 3 * s, y: 10 * s))
            p.line(to: .init(x: 8 * s, y: 10 * s))
            // Clock circle.
            p.addEllipse(in: CGRect(x: 10, y: 10, width: 12, height: 12).scaled(by: s))

        case .tracks:
            // Teardrop pin outline + inner circle.
            // SVG: M20 10c0 4.993-5.539 10.193-7.399 11.799a1 1 0 0 1-1.202 0C9.539 20.193 4 14.993 4 10a8 8 0 0 1 16 0
            p.move(to: .init(x: 20 * s, y: 10 * s))
            p.cubicRel(
                from: .init(x: 20, y: 10),
                c1: .init(x: 0, y: 4.993),
                c2: .init(x: -5.539, y: 10.193),
                to: .init(x: -7.399, y: 11.799),
                s: s)
            p.arcRel(
                from: .init(x: 12.601, y: 21.799),
                radius: 1,
                largeArc: false,
                sweep: true,
                delta: .init(x: -1.202, y: 0),
                s: s)
            p.cubic(
                to: .init(x: 4, y: 10),
                c1: .init(x: 9.539, y: 20.193),
                c2: .init(x: 4, y: 14.993),
                s: s)
            p.arcRel(
                from: .init(x: 4, y: 10),
                radius: 8,
                largeArc: false,
                sweep: true,
                delta: .init(x: 16, y: 0),
                s: s)
            // Inner dot.
            p.addEllipse(in: CGRect(x: 9, y: 7, width: 6, height: 6).scaled(by: s))

        case .cars:
            // Chassis silhouette with two wheel wells.
            // SVG: M19 17h2c.6 0 1-.4 1-1v-3c0-.9-.7-1.7-1.5-1.9C18.7 10.6 16 10 16 10s-1.3-1.4-2.2-2.3c-.5-.4-1.1-.7-1.8-.7H5c-.6 0-1.1.4-1.4.9l-1.4 2.9A3.7 3.7 0 0 0 2 12v4c0 .6.4 1 1 1h2
            p.move(to: .init(x: 19 * s, y: 17 * s))
            p.line(to: .init(x: 21 * s, y: 17 * s))
            p.cubicRel(
                from: .init(x: 21, y: 17),
                c1: .init(x: 0.6, y: 0),
                c2: .init(x: 1, y: -0.4),
                to: .init(x: 1, y: -1),
                s: s)
            p.line(to: .init(x: 22 * s, y: 13 * s))
            p.cubicRel(
                from: .init(x: 22, y: 13),
                c1: .init(x: 0, y: -0.9),
                c2: .init(x: -0.7, y: -1.7),
                to: .init(x: -1.5, y: -1.9),
                s: s)
            p.cubic(
                to: .init(x: 16, y: 10),
                c1: .init(x: 18.7, y: 10.6),
                c2: .init(x: 16, y: 10),
                s: s)
            p.cubicRel(
                from: .init(x: 16, y: 10),
                c1: .init(x: 0, y: 0),
                c2: .init(x: -1.3, y: -1.4),
                to: .init(x: -2.2, y: -2.3),
                s: s)
            p.cubicRel(
                from: .init(x: 13.8, y: 7.7),
                c1: .init(x: -0.5, y: -0.4),
                c2: .init(x: -1.1, y: -0.7),
                to: .init(x: -1.8, y: -0.7),
                s: s)
            p.line(to: .init(x: 5 * s, y: 7 * s))
            p.cubicRel(
                from: .init(x: 5, y: 7),
                c1: .init(x: -0.6, y: 0),
                c2: .init(x: -1.1, y: 0.4),
                to: .init(x: -1.4, y: 0.9),
                s: s)
            p.line(to: .init(x: 2.2 * s, y: 10.8 * s))
            p.arcRel(
                from: .init(x: 2.2, y: 10.8),
                radius: 3.7,
                largeArc: false,
                sweep: false,
                delta: .init(x: -0.2, y: 1.2),
                s: s)
            p.line(to: .init(x: 2 * s, y: 16 * s))
            p.cubicRel(
                from: .init(x: 2, y: 16),
                c1: .init(x: 0, y: 0.6),
                c2: .init(x: 0.4, y: 1),
                to: .init(x: 1, y: 1),
                s: s)
            p.line(to: .init(x: 5 * s, y: 17 * s))
            // Front wheel.
            p.addEllipse(in: CGRect(x: 5, y: 15, width: 4, height: 4).scaled(by: s))
            // Axle.
            p.move(to: .init(x: 9 * s, y: 17 * s))
            p.line(to: .init(x: 15 * s, y: 17 * s))
            // Rear wheel.
            p.addEllipse(in: CGRect(x: 15, y: 15, width: 4, height: 4).scaled(by: s))

        case .races:
            // Pennant flag: single curved silhouette, vertical pole
            // anchored at x=4.
            // SVG: M4 22V4a1 1 0 0 1 .4-.8A6 6 0 0 1 8 2c3 0 5 2 7.333 2q2 0 3.067-.8A1 1 0 0 1 20 4v10a1 1 0 0 1-.4.8A6 6 0 0 1 16 16c-3 0-5-2-8-2a6 6 0 0 0-4 1.528
            p.move(to: .init(x: 4 * s, y: 22 * s))
            p.line(to: .init(x: 4 * s, y: 4 * s))
            p.arcRel(
                from: .init(x: 4, y: 4),
                radius: 1,
                largeArc: false,
                sweep: true,
                delta: .init(x: 0.4, y: -0.8),
                s: s)
            p.arcRel(
                from: .init(x: 4.4, y: 3.2),
                radius: 6,
                largeArc: false,
                sweep: true,
                delta: .init(x: 3.6, y: -1.2),
                s: s)
            p.cubic(
                to: .init(x: 15.333, y: 4),
                c1: .init(x: 11, y: 2),
                c2: .init(x: 13, y: 4),
                s: s)
            // q-command: quadratic relative. `q2 0 3.067-.8` means
            // control (+2,+0) endpoint (+3.067,-0.8).
            p.quadRel(
                from: .init(x: 15.333, y: 4),
                control: .init(x: 2, y: 0),
                delta: .init(x: 3.067, y: -0.8),
                s: s)
            p.arcRel(
                from: .init(x: 18.4, y: 3.2),
                radius: 1,
                largeArc: false,
                sweep: true,
                delta: .init(x: 1.6, y: 0.8),
                s: s)
            p.line(to: .init(x: 20 * s, y: 14 * s))
            p.arcRel(
                from: .init(x: 20, y: 14),
                radius: 1,
                largeArc: false,
                sweep: true,
                delta: .init(x: -0.4, y: 0.8),
                s: s)
            p.arcRel(
                from: .init(x: 19.6, y: 14.8),
                radius: 6,
                largeArc: false,
                sweep: true,
                delta: .init(x: -3.6, y: 1.2),
                s: s)
            p.cubic(
                to: .init(x: 8, y: 14),
                c1: .init(x: 13, y: 16),
                c2: .init(x: 11, y: 14),
                s: s)
            p.arcRel(
                from: .init(x: 8, y: 14),
                radius: 6,
                largeArc: false,
                sweep: false,
                delta: .init(x: -4, y: 1.528),
                s: s)

        case .profile:
            // Shoulders + head outline. Exactly matches lucide's
            // `user` glyph: rounded trapezoid for the shoulders and a
            // circle for the head.
            p.move(to: .init(x: 19 * s, y: 21 * s))
            p.line(to: .init(x: 19 * s, y: 19 * s))
            p.arcRel(
                from: .init(x: 19, y: 19),
                radius: 4,
                largeArc: false,
                sweep: false,
                delta: .init(x: -4, y: -4),
                s: s)
            p.line(to: .init(x: 9 * s, y: 15 * s))
            p.arcRel(
                from: .init(x: 9, y: 15),
                radius: 4,
                largeArc: false,
                sweep: false,
                delta: .init(x: -4, y: 4),
                s: s)
            p.line(to: .init(x: 5 * s, y: 21 * s))
            p.addEllipse(in: CGRect(x: 8, y: 3, width: 8, height: 8).scaled(by: s))

        case .moments:
            // Four-point star — big center star, small decorations.
            // Big star path data (simplified to its polygon points —
            // lucide draws it via a cubic path but the shape is a
            // smooth 4-pointed burst; we approximate with Bezier
            // segments matching the lucide rendering).
            p.move(to: .init(x: 12 * s, y: 2 * s))
            p.line(to: .init(x: 13.051 * s, y: 8.37 * s))
            p.line(to: .init(x: 19.188 * s, y: 9.43 * s))
            p.line(to: .init(x: 13.051 * s, y: 10.482 * s))
            p.line(to: .init(x: 12 * s, y: 16.812 * s))
            p.line(to: .init(x: 10.949 * s, y: 10.482 * s))
            p.line(to: .init(x: 4.812 * s, y: 9.43 * s))
            p.line(to: .init(x: 10.949 * s, y: 8.37 * s))
            p.closeSubpath()
            // Small cross decoration (top right).
            p.move(to: .init(x: 20 * s, y: 2 * s))
            p.line(to: .init(x: 20 * s, y: 6 * s))
            p.move(to: .init(x: 22 * s, y: 4 * s))
            p.line(to: .init(x: 18 * s, y: 4 * s))
            // Bottom-left dot (rendered as a tiny circle).
            p.addEllipse(in: CGRect(x: 2, y: 18, width: 4, height: 4).scaled(by: s))
        }

        return p
    }
}

// MARK: - Path conveniences

private extension CGRect {
    func scaled(by factor: CGFloat) -> CGRect {
        CGRect(x: origin.x * factor, y: origin.y * factor,
               width: size.width * factor, height: size.height * factor)
    }
}

private extension Path {
    /// `M sx sy L ex ey` in one call.
    mutating func line(from: CGPoint, to: CGPoint, s: CGFloat) {
        move(to: CGPoint(x: from.x * s, y: from.y * s))
        addLine(to: CGPoint(x: to.x * s, y: to.y * s))
    }

    /// Cubic-relative: start at `from`, delta control points and end.
    mutating func cubicRel(from: CGPoint, c1: CGPoint, c2: CGPoint, to delta: CGPoint, s: CGFloat) {
        move(to: CGPoint(x: from.x * s, y: from.y * s))
        addCurve(
            to: CGPoint(x: (from.x + delta.x) * s, y: (from.y + delta.y) * s),
            control1: CGPoint(x: (from.x + c1.x) * s, y: (from.y + c1.y) * s),
            control2: CGPoint(x: (from.x + c2.x) * s, y: (from.y + c2.y) * s))
    }

    /// Cubic-absolute continuation — assumes current point is known.
    mutating func cubic(to end: CGPoint, c1: CGPoint, c2: CGPoint, s: CGFloat) {
        addCurve(
            to: CGPoint(x: end.x * s, y: end.y * s),
            control1: CGPoint(x: c1.x * s, y: c1.y * s),
            control2: CGPoint(x: c2.x * s, y: c2.y * s))
    }

    /// Quadratic-relative — like SVG's lower-case `q` command.
    mutating func quadRel(from: CGPoint, control: CGPoint, delta: CGPoint, s: CGFloat) {
        addQuadCurve(
            to: CGPoint(x: (from.x + delta.x) * s, y: (from.y + delta.y) * s),
            control: CGPoint(x: (from.x + control.x) * s, y: (from.y + control.y) * s))
    }

    /// SVG-arc relative command. Converts to a centered `addArc` by
    /// solving for the implied circle center when rx == ry and
    /// rotation is 0 (which is true for every arc in the lucide icons
    /// we render). Returns the new current point via the next call's
    /// `from` parameter — callers pass `from` explicitly because
    /// `Path` doesn't expose its current point.
    mutating func arcRel(
        from start: CGPoint,
        radius: CGFloat,
        largeArc: Bool,
        sweep: Bool,
        delta: CGPoint,
        s: CGFloat
    ) {
        let end = CGPoint(x: start.x + delta.x, y: start.y + delta.y)
        let r = radius

        // Compute the circle center lying on the perpendicular
        // bisector of the start→end chord.
        let mid = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
        let chord = CGPoint(x: end.x - start.x, y: end.y - start.y)
        let chordLen = hypot(chord.x, chord.y)
        let half = chordLen / 2
        // Clamp radius when the chord exceeds the diameter — same
        // rule SVG renderers use to avoid NaN when data is slightly off.
        let safeR = max(r, half)
        let h = sqrt(max(0, safeR * safeR - half * half))
        // Unit perpendicular to the chord.
        let perp = CGPoint(x: -chord.y / chordLen, y: chord.x / chordLen)
        // Side choice — matches SVG's large-arc + sweep combination.
        let side: CGFloat = (largeArc == sweep) ? -1 : 1
        let center = CGPoint(
            x: mid.x + h * perp.x * side,
            y: mid.y + h * perp.y * side)

        let startAngle = atan2(start.y - center.y, start.x - center.x)
        let endAngle = atan2(end.y - center.y, end.x - center.x)
        // SwiftUI's `addArc` draws counterclockwise when `clockwise`
        // is false. SVG `sweep=1` means positive-angle direction in
        // the SVG y-down system, which is visually clockwise, i.e.
        // SwiftUI `clockwise: false` in the same y-down space.
        addArc(
            center: CGPoint(x: center.x * s, y: center.y * s),
            radius: safeR * s,
            startAngle: Angle(radians: Double(startAngle)),
            endAngle: Angle(radians: Double(endAngle)),
            clockwise: !sweep)
    }
}
