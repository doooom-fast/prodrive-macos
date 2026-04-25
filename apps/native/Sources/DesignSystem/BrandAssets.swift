import SwiftUI
import AppKit

// MARK: - Track silhouette

/// Renders the track silhouette as a SwiftUI `Path` by parsing the
/// SVG `d=` attribute string returned by the server's dashboard
/// `lookups` payload. Scales to fit the given frame. Never falls
/// back to an SF Symbol — callers pass a `TrackLookup` only when
/// they've confirmed the entry exists, otherwise this renders empty.
///
/// The server's track paths use a 0–100 viewBox (see `track-svg.ts`
/// in the web repo's `csvToSvg()` pipeline) so the transform is just
/// a uniform scale to the view's bounds.
struct TrackSilhouette: View {
    let svgPath: String
    var stroke: Color = Palette.textSecondary
    var lineWidth: CGFloat = 1.2

    var body: some View {
        GeometryReader { geo in
            if let path = SVGPathParser.parse(svgPath) {
                path
                    .applying(
                        .init(scaleX: geo.size.width / 100,
                              y: geo.size.height / 100)
                    )
                    .stroke(stroke, style: StrokeStyle(
                        lineWidth: lineWidth,
                        lineCap: .round,
                        lineJoin: .round))
            }
        }
    }
}

// MARK: - Brand logo

/// Renders a manufacturer/brand logo using whichever of the
/// server's provided formats we got — SVG markup (preferred, crisp
/// at any size) or base64 PNG. Both come from the `carLogos` DB
/// table via the dashboard lookup bundle.
struct BrandLogo: View {
    let lookup: Dashboard.CarLookup
    var height: CGFloat = 20

    var body: some View {
        Group {
            // Prefer PNG when the server has one — NSImage's SVG
            // renderer flattens complex paths (strokes, inline style
            // blocks, masks) into solid silhouettes on some macOS
            // versions, which is what caused the Mazda emblem to read
            // as a blob. PNG is pixel-accurate to whatever asset the
            // uploader seeded, which matches what the web shows.
            if let pngBase64 = lookup.logoPng,
               let data = Data(base64Encoded: pngBase64),
               let image = NSImage(data: data) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
            } else if let svg = lookup.logoSvg,
                      let image = SVGRenderer.rasterize(svg, maxDimension: height * 3) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                // Last-resort: initial letter on the brand color.
                Text(String((lookup.manufacturer ?? "?").prefix(1)).uppercased())
                    .font(.system(size: height * 0.5, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(width: height, height: height)
                    .background(Circle().fill(lookupTint))
            }
        }
        .frame(height: height)
        .accessibilityLabel(lookup.manufacturer ?? "Manufacturer logo")
    }

    private var lookupTint: Color {
        guard let hex = lookup.color else { return Palette.brand }
        return Color(hex: hex)
    }
}

// MARK: - Track photo

/// Remote track photo (Wikimedia) from the dashboard lookup.
/// Caller is responsible for aspect ratio + clipping.
struct TrackImage: View {
    let url: URL?

    var body: some View {
        Group {
            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        Palette.bgElevated
                    }
                }
            } else {
                Palette.bgElevated
            }
        }
    }
}

// MARK: - SVG parsing helpers

/// Minimal SVG path parser — handles the `M / L / C / Q / Z`
/// commands (both absolute + relative forms) that appear in the
/// server's track silhouettes. Not a complete SVG parser; deliberate
/// — our path generator emits only these commands (see `csvToSvg()`
/// in the web repo).
enum SVGPathParser {
    static func parse(_ d: String) -> Path? {
        var path = Path()
        var current = CGPoint.zero
        var start = CGPoint.zero
        var lastControl = CGPoint.zero

        let scanner = Scanner(string: d)
        scanner.charactersToBeSkipped = CharacterSet.whitespacesAndNewlines.union(.init(charactersIn: ","))

        while !scanner.isAtEnd {
            guard let cmd = scanner.scanCharacter() else { break }
            let relative = cmd.isLowercase

            switch cmd.lowercased() {
            case "m":
                while let p = readPoint(scanner) {
                    let to = relative ? CGPoint(x: current.x + p.x, y: current.y + p.y) : p
                    path.move(to: to)
                    current = to
                    start = to
                }
            case "l":
                while let p = readPoint(scanner) {
                    let to = relative ? CGPoint(x: current.x + p.x, y: current.y + p.y) : p
                    path.addLine(to: to)
                    current = to
                }
            case "h":
                while let x = readNumber(scanner) {
                    let to = CGPoint(x: relative ? current.x + x : x, y: current.y)
                    path.addLine(to: to)
                    current = to
                }
            case "v":
                while let y = readNumber(scanner) {
                    let to = CGPoint(x: current.x, y: relative ? current.y + y : y)
                    path.addLine(to: to)
                    current = to
                }
            case "c":
                while let c1 = readPoint(scanner), let c2 = readPoint(scanner), let p = readPoint(scanner) {
                    let control1 = relative ? CGPoint(x: current.x + c1.x, y: current.y + c1.y) : c1
                    let control2 = relative ? CGPoint(x: current.x + c2.x, y: current.y + c2.y) : c2
                    let to = relative ? CGPoint(x: current.x + p.x, y: current.y + p.y) : p
                    path.addCurve(to: to, control1: control1, control2: control2)
                    current = to
                    lastControl = control2
                }
            case "s":
                while let c2 = readPoint(scanner), let p = readPoint(scanner) {
                    let control1 = CGPoint(
                        x: 2 * current.x - lastControl.x,
                        y: 2 * current.y - lastControl.y)
                    let control2 = relative ? CGPoint(x: current.x + c2.x, y: current.y + c2.y) : c2
                    let to = relative ? CGPoint(x: current.x + p.x, y: current.y + p.y) : p
                    path.addCurve(to: to, control1: control1, control2: control2)
                    current = to
                    lastControl = control2
                }
            case "q":
                while let c = readPoint(scanner), let p = readPoint(scanner) {
                    let control = relative ? CGPoint(x: current.x + c.x, y: current.y + c.y) : c
                    let to = relative ? CGPoint(x: current.x + p.x, y: current.y + p.y) : p
                    path.addQuadCurve(to: to, control: control)
                    current = to
                    lastControl = control
                }
            case "z":
                path.addLine(to: start)
                path.closeSubpath()
                current = start
            default:
                // Unknown command — skip the next number(s) defensively.
                while readNumber(scanner) != nil {}
            }
        }

        return path.isEmpty ? nil : path
    }

    private static func readNumber(_ s: Scanner) -> CGFloat? {
        var d: Double = 0
        return s.scanDouble(&d) ? CGFloat(d) : nil
    }

    private static func readPoint(_ s: Scanner) -> CGPoint? {
        guard let x = readNumber(s), let y = readNumber(s) else { return nil }
        return CGPoint(x: x, y: y)
    }
}

// MARK: - SVG rasterizer (for brand logos)

/// Rasterizes an SVG markup string to an NSImage via WebKit's
/// offline layout. Used for brand logos which arrive as full SVG
/// XML from the server (headers + paths + gradients), not the
/// simplified `d=` form TrackSilhouette handles. Caches per-source
/// so we don't re-rasterize on every view update.
enum SVGRenderer {
    private static var cache: [String: NSImage] = [:]

    static func rasterize(_ svg: String, maxDimension: CGFloat) -> NSImage? {
        let cacheKey = "\(svg.hashValue)-\(Int(maxDimension))"
        if let cached = cache[cacheKey] { return cached }

        // Encode as data URL so NSImage can decode.
        guard let encoded = svg.data(using: .utf8) else { return nil }
        guard let image = NSImage(data: encoded) else { return nil }
        // NSImage initialized from SVG data uses the SVG's intrinsic
        // size; rescale to target dimension.
        let ratio = maxDimension / max(image.size.width, image.size.height)
        image.size = NSSize(
            width: image.size.width * ratio,
            height: image.size.height * ratio)
        cache[cacheKey] = image
        return image
    }
}
