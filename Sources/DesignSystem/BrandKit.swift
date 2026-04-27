import SwiftUI

/// Shared brand primitives the dashboard (and everything we'll build after)
/// relies on. This is the Swift-native expression of the web app's design
/// tokens — same hex values, same vibes. Defining them here as a single
/// source of truth means views never reach for `Color(hex: "#e53935")`
/// one-off.
///
/// These are compile-time constants rather than runtime lookups against
/// `DesignTokenStore`. That store is `@MainActor`-isolated and calling it
/// from static computed properties required the whole `Palette` to be
/// `@MainActor` too, which made every downstream struct's default-value
/// initializer actor-isolated — a noisy constraint for values that
/// almost never change at runtime anyway. If/when a view needs *live*
/// tokens (e.g. after `/api/v1/tokens/native` refresh), it can observe
/// `DesignTokenStore.shared.resolved` directly and use those colors
/// instead of `Palette.*`.
enum Palette {
    // Backgrounds
    static let bgBase      = Color(hex: "#0a0a14")
    static let bgSurface   = Color(hex: "#101020").opacity(0.9)
    static let bgPanel     = Color(hex: "#0a0a14").opacity(0.95)
    static let bgElevated  = Color(hex: "#14142a")

    // RaceCor red
    static let brand       = Color(hex: "#e53935")
    static let brandMid    = Color(hex: "#b02020")
    static let brandDark   = Color(hex: "#700010")

    // Text
    static let textPrimary   = Color(hex: "#e8e8f0")
    static let textSecondary = Color.white.opacity(0.69)
    static let textDim       = Color.white.opacity(0.48)
    static let textMuted     = Color.white.opacity(0.32)

    // Borders
    static let borderSubtle = Color.white.opacity(0.14)
    static let borderAccent = Color(hex: "#e53935").opacity(0.35)

    // Semantic
    static let success = Color(hex: "#34c759")
    static let warning = Color(hex: "#ff9f0a")
}

// ─── Logomark ────────────────────────────────────────────────────────────

/// RaceCor logomark, rendered entirely in SwiftUI Paths from the SVG's
/// coordinate data. No asset catalog, no bundled PNG, no file loading —
/// the Xcode asset-catalog pipeline kept failing us, so this draws the
/// logomark geometrically. Always renders; never "missing".
///
/// Coordinates taken directly from `racecor-logomark.svg`'s six
/// `<path>` elements (viewBox: 185.3 258.9 224.3 93.3). Each path is a
/// closed polygon of straight-line segments, so SwiftUI `Path` can
/// reproduce them exactly.
struct Logomark: View {
    enum Tone { case white, color }

    let height: CGFloat
    let tone: Tone

    init(height: CGFloat = 32, tone: Tone = .white) {
        self.height = height
        self.tone = tone
    }

    var body: some View {
        RaceCorLogomarkShape(tone: tone)
            .frame(height: height)
            .fixedSize()
            .accessibilityLabel("RaceCor Pro Drive")
    }
}

/// Pure-SwiftUI rendering of the RaceCor logomark from the source SVG.
struct RaceCorLogomarkShape: View {
    let tone: Logomark.Tone

    // Source SVG viewBox: 185.3 258.9 224.3 93.3 (≈2.4:1 aspect).
    private static let vbX: CGFloat = 185.3
    private static let vbY: CGFloat = 258.9
    private static let vbW: CGFloat = 224.3
    private static let vbH: CGFloat = 93.3

    /// Six polygon paths — points extracted straight from the SVG's
    /// `d="M x y L x y ..."` attributes. Order matters: later paths
    /// render on top of earlier ones.
    private static let polygons: [(fill: String, points: [CGPoint])] = [
        // Rightmost red chevron (top)
        ("#ED3733", [
            .init(x: 351.21875, y: 349.621094),
            .init(x: 379.378906, y: 349.621094),
            .init(x: 407.550781, y: 305.335938),
            .init(x: 407.550781, y: 304.695312),
            .init(x: 380.582031, y: 260.863281),
            .init(x: 350.019531, y: 260.863281),
            .init(x: 380.988281, y: 305.816406),
        ]),
        // Right dark chevron shadow
        ("#711111", [
            .init(x: 377.84375,  y: 260.863281),
            .init(x: 349.6875,   y: 260.863281),
            .init(x: 321.515625, y: 305.148438),
            .init(x: 321.515625, y: 305.789062),
            .init(x: 348.484375, y: 349.621094),
            .init(x: 379.046875, y: 349.621094),
            .init(x: 348.074219, y: 304.667969),
        ]),
        // Leftmost red chevron
        ("#ED3733", [
            .init(x: 273.070312, y: 260.863281),
            .init(x: 244.910156, y: 260.863281),
            .init(x: 244.828125, y: 260.992188),
            .init(x: 238.203125, y: 260.863281),
            .init(x: 223.054688, y: 284.605469),
            .init(x: 230.117188, y: 284.121094),
            .init(x: 224.515625, y: 290.898438),
            .init(x: 206.445312, y: 290.898438),
            .init(x: 187.273438, y: 306.226562),
            .init(x: 215.648438, y: 305.613281),
            .init(x: 216.738281, y: 305.789062),
            .init(x: 243.710938, y: 349.621094),
            .init(x: 271.269531, y: 349.621094),
            .init(x: 244.300781, y: 304.667969),
        ]),
        // Center red-mid chevron
        ("#B42226", [
            .init(x: 301.238281, y: 268.25),
            .init(x: 307.042969, y: 261.410156),
            .init(x: 279.882812, y: 261.410156),
            .init(x: 250.710938, y: 305.695312),
            .init(x: 250.710938, y: 306.335938),
            .init(x: 281.683594, y: 350.167969),
            .init(x: 335.941406, y: 350.167969),
            .init(x: 362.914062, y: 306.335938),
            .init(x: 362.914062, y: 305.695312),
            .init(x: 336.355469, y: 305.21875),
            .init(x: 335.503906, y: 304.609375),
            .init(x: 329.910156, y: 312.726562),
            .init(x: 306.8125,   y: 348.09375),
            .init(x: 277.269531, y: 305.21875),
            .init(x: 292.726562, y: 280.773438),
        ]),
        // Center dark shadow
        ("#711111", [
            .init(x: 314.476562, y: 304.667969),
            .init(x: 329.855469, y: 282.042969),
            .init(x: 302.617188, y: 282.042969),
            .init(x: 287.917969, y: 305.148438),
            .init(x: 287.917969, y: 305.789062),
            .init(x: 314.886719, y: 349.621094),
            .init(x: 345.449219, y: 349.621094),
        ]),
        // Top dark bridge
        ("#711111", [
            .init(x: 344.246094, y: 260.863281),
            .init(x: 316.085938, y: 260.863281),
            .init(x: 305.480469, y: 277.539062),
            .init(x: 332.914062, y: 277.539062),
        ]),
    ]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(Self.polygons.indices, id: \.self) { i in
                    let entry = Self.polygons[i]
                    shape(for: entry.points, in: geo.size)
                        .fill(fillColor(hex: entry.fill))
                }
            }
        }
        .aspectRatio(Self.vbW / Self.vbH, contentMode: .fit)
    }

    /// Build a SwiftUI `Path` by mapping SVG coordinates into the given
    /// render size.
    private func shape(for pts: [CGPoint], in size: CGSize) -> Path {
        let scaleX = size.width / Self.vbW
        let scaleY = size.height / Self.vbH
        return Path { path in
            guard let first = pts.first else { return }
            path.move(to: CGPoint(
                x: (first.x - Self.vbX) * scaleX,
                y: (first.y - Self.vbY) * scaleY))
            for pt in pts.dropFirst() {
                path.addLine(to: CGPoint(
                    x: (pt.x - Self.vbX) * scaleX,
                    y: (pt.y - Self.vbY) * scaleY))
            }
            path.closeSubpath()
        }
    }

    /// Tone-aware color mapping. `.white` flattens all fills to white for
    /// on-dark-background placements. `.color` uses the brand red ramp.
    private func fillColor(hex: String) -> Color {
        switch tone {
        case .white: return .white
        case .color: return Color(hex: hex)
        }
    }
}

// ─── Sparkline ───────────────────────────────────────────────────────────

/// A tiny line chart for iRating history. Uses SwiftUI's `Canvas` so it's
/// cheap to render many of these at once. `points` is a series of Y values
/// (X is implicit — evenly spaced left→right).
struct Sparkline: View {
    let values: [Int]
    let trend: Int   // -1 / 0 / 1
    let lineWidth: CGFloat
    let showFill: Bool

    init(values: [Int], trend: Int = 0, lineWidth: CGFloat = 1.5, showFill: Bool = true) {
        self.values = values
        self.trend = trend
        self.lineWidth = lineWidth
        self.showFill = showFill
    }

    /// Color for the sparkline matches the trend: up = green, down = red,
    /// flat = dim. This mirrors `IRatingSparkline` in the web app.
    private var lineColor: Color {
        switch trend {
        case 1:  return Palette.success
        case -1: return Palette.brand
        default: return Palette.textDim
        }
    }

    var body: some View {
        Canvas { context, size in
            guard values.count >= 2 else { return }

            let minV = values.min().map(Double.init) ?? 0
            let maxV = values.max().map(Double.init) ?? 1
            let range = max(1.0, maxV - minV)

            func point(for i: Int) -> CGPoint {
                let x = CGFloat(i) / CGFloat(values.count - 1) * size.width
                let normalized = (Double(values[i]) - minV) / range
                // Leave a 2px top/bottom gutter so points don't kiss the edge
                let y = size.height - 2 - CGFloat(normalized) * (size.height - 4)
                return CGPoint(x: x, y: y)
            }

            // Fill under the line — gives the sparkline visual weight.
            if showFill {
                var fillPath = Path()
                fillPath.move(to: CGPoint(x: 0, y: size.height))
                for i in values.indices { fillPath.addLine(to: point(for: i)) }
                fillPath.addLine(to: CGPoint(x: size.width, y: size.height))
                fillPath.closeSubpath()
                context.fill(fillPath, with: .color(lineColor.opacity(0.18)))
            }

            var linePath = Path()
            linePath.move(to: point(for: 0))
            for i in 1..<values.count { linePath.addLine(to: point(for: i)) }
            context.stroke(linePath, with: .color(lineColor), lineWidth: lineWidth)

            // Highlight the final point so the eye has an anchor.
            let last = point(for: values.count - 1)
            let dotSize: CGFloat = 3
            let dotRect = CGRect(x: last.x - dotSize, y: last.y - dotSize,
                                 width: dotSize * 2, height: dotSize * 2)
            context.fill(Path(ellipseIn: dotRect), with: .color(lineColor))
        }
    }
}

// ─── Dark Panel Style ────────────────────────────────────────────────────

/// ViewModifier that gives a container the "elevated frosted card" look.
///
/// On macOS 26 Tahoe (and iOS 26) it uses Apple's real Liquid Glass
/// material via `.glassEffect(in:)` — the new dynamic refractive
/// surface introduced at WWDC 2025. On older OSes (we still ship to
/// macOS 14+) it falls back to `.ultraThinMaterial`, which is a
/// frosted blur that LOOKS like glass but doesn't refract — the
/// pre-Tahoe approximation that's been in this codebase since the
/// first SwiftUI port.
///
/// Both paths preserve the same tint overlay for legibility against
/// bright livery photos and the same hairline border for edge
/// definition, so the panel reads as the same surface on both OS
/// generations — Tahoe just gets the upgraded treatment for free.
struct PanelStyle: ViewModifier {
    var tint: Color = Palette.bgPanel.opacity(0.35)
    var borderColor: Color = Palette.borderSubtle
    var cornerRadius: CGFloat = 12
    var padding: CGFloat = 16
    var material: Material = .ultraThinMaterial

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .liquidGlassBackground(
                cornerRadius: cornerRadius,
                fallbackMaterial: material,
                tint: tint
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: 1)
            )
    }
}

extension View {
    func panel(tint: Color = Palette.bgPanel.opacity(0.35),
               border: Color = Palette.borderSubtle,
               cornerRadius: CGFloat = 12,
               padding: CGFloat = 16,
               material: Material = .ultraThinMaterial) -> some View {
        modifier(PanelStyle(tint: tint, borderColor: border,
                            cornerRadius: cornerRadius, padding: padding,
                            material: material))
    }

    /// Accent panel with a red hairline border — hero / primary CTAs.
    func panelAccent(cornerRadius: CGFloat = 12, padding: CGFloat = 16) -> some View {
        modifier(PanelStyle(tint: Palette.bgPanel.opacity(0.35),
                            borderColor: Palette.borderAccent,
                            cornerRadius: cornerRadius, padding: padding,
                            material: .ultraThinMaterial))
    }

    /// Real Liquid Glass on macOS 26+ / iOS 26+, frosted-blur fallback
    /// on older OSes. Centralizes the availability gate so call sites
    /// don't each grow their own `if #available` block.
    ///
    /// Why a `tint` parameter on the Tahoe branch: the Liquid Glass
    /// material is highly transparent — over bright livery photos
    /// there isn't enough contrast for body text. Layering a low-
    /// opacity color over the glass restores legibility while still
    /// letting the refraction read. The tint sits ABOVE the glass
    /// (last `.background()` is the bottom layer in SwiftUI), so the
    /// stack from back to front is: livery photo → glass → tint →
    /// content.
    @ViewBuilder
    func liquidGlassBackground(
        cornerRadius: CGFloat,
        fallbackMaterial: Material = .ultraThinMaterial,
        tint: Color = .clear
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if #available(macOS 26.0, iOS 26.0, *) {
            // The `in:` parameter masks the glass to the rounded
            // rectangle. Without it, `.glassEffect()` defaults to
            // Capsule, which renders a pill-shaped glass card inside
            // the panel — visible as a "second card" inset behind
            // the real content. Always pass `in:` to match the
            // surrounding stroke border's shape.
            self.background(
                ZStack {
                    Color.clear.glassEffect(in: shape)
                    shape.fill(tint)
                }
            )
        } else {
            self.background(
                ZStack {
                    shape.fill(fallbackMaterial)
                    shape.fill(tint)
                }
            )
        }
    }
}

// ─── Brand Glow Background ───────────────────────────────────────────────

/// The diffuse red glow behind the hero section of the web dashboard.
/// Use as a `.background` or standalone ZStack layer. Purely decorative.
struct BrandGlow: View {
    var intensity: Double = 0.18
    var body: some View {
        RadialGradient(
            gradient: Gradient(colors: [
                Palette.brand.opacity(intensity),
                Palette.brand.opacity(0),
            ]),
            center: .center,
            startRadius: 10,
            endRadius: 280
        )
        .blur(radius: 40)
        .allowsHitTesting(false)
    }
}
