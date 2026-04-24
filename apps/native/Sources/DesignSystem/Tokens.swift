import SwiftUI

struct DesignTokens {
    // Colors
    static let bgPrimary = Color(hex: "#0a0a14")
    static let bgSecondary = Color(hex: "#1a1a28")
    static let k10Red = Color(hex: "#e53935")
    static let k10Accent = Color(hex: "#1e88e5")
    static let success = Color(hex: "#43a047")
    static let warning = Color(hex: "#fb8c00")
    static let error = Color(hex: "#e53935")

    // Typography
    static let fontHeadline = Font.system(size: 20, weight: .bold)
    static let fontTitle = Font.system(size: 24, weight: .bold)
    static let fontBody = Font.system(size: 16)
    static let fontCaption = Font.system(size: 12)
}

extension Color {
    /// Accepts `#RGB`, `#RRGGBB`, or `#RRGGBBAA` (case-insensitive).
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        // Expand shorthand #RGB → #RRGGBB
        if s.count == 3 {
            s = s.map { "\($0)\($0)" }.joined()
        }
        let value = UInt64(s, radix: 16) ?? 0
        let r, g, b, a: Double
        switch s.count {
        case 8: // RRGGBBAA
            r = Double((value >> 24) & 0xff) / 255
            g = Double((value >> 16) & 0xff) / 255
            b = Double((value >> 8) & 0xff) / 255
            a = Double(value & 0xff) / 255
        default: // RRGGBB (or fallback)
            r = Double((value >> 16) & 0xff) / 255
            g = Double((value >> 8) & 0xff) / 255
            b = Double(value & 0xff) / 255
            a = 1.0
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }

    /// Parses `rgb(r,g,b)` or `rgba(r,g,b,a)` with optional whitespace and
    /// `%`-formatted components. Falls back to opaque black if the string
    /// doesn't match. Used by DesignTokenStore when a token value is in
    /// functional-notation form rather than hex.
    init(rgba raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let open = trimmed.firstIndex(of: "("),
              let close = trimmed.lastIndex(of: ")"), open < close else {
            self.init(.sRGB, red: 0, green: 0, blue: 0, opacity: 1)
            return
        }
        let inside = trimmed[trimmed.index(after: open)..<close]
        let parts = inside
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }

        func parseChannel(_ s: String) -> Double {
            if s.hasSuffix("%") {
                return (Double(s.dropLast()) ?? 0) / 100.0
            }
            // 0–255 component → normalize to 0–1
            return (Double(s) ?? 0) / 255.0
        }
        func parseAlpha(_ s: String) -> Double {
            if s.hasSuffix("%") { return (Double(s.dropLast()) ?? 0) / 100.0 }
            return max(0, min(1, Double(s) ?? 1))
        }

        let r = parts.count > 0 ? parseChannel(parts[0]) : 0
        let g = parts.count > 1 ? parseChannel(parts[1]) : 0
        let b = parts.count > 2 ? parseChannel(parts[2]) : 0
        let a = parts.count > 3 ? parseAlpha(parts[3]) : 1.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}
