import SwiftUI

/// Floating HUD that paints over the video frame: track + car header,
/// playhead time, position / lap / speed. Re-renders when the parent
/// view's `frame` binding changes (driven by the AVPlayer time observer).
struct TelemetryOverlay: View {
    let header: BundleHeader
    let frame: TelemetryFrame?
    let playheadSeconds: Double

    var body: some View {
        ZStack {
            VStack {
                topRow
                Spacer()
                bottomRow
            }
            .padding(14)
        }
        .allowsHitTesting(false) // never intercept clicks meant for the player
    }

    // MARK: - Top row: track + car (left), playhead (right)

    private var topRow: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                if let track = header.race.track {
                    Text(track)
                        .font(.system(size: 13, weight: .semibold, design: .default))
                        .foregroundColor(Palette.textPrimary)
                        .shadow(color: .black.opacity(0.6), radius: 2, x: 0, y: 1)
                }
                if let car = header.race.car {
                    Text(car)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Palette.textSecondary)
                        .shadow(color: .black.opacity(0.6), radius: 2, x: 0, y: 1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(formatTime(playheadSeconds))
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(Palette.textPrimary)
                    .shadow(color: .black.opacity(0.6), radius: 2, x: 0, y: 1)
                if let frame = frame, let frameIdx = frame.frame {
                    Text("Frame \(frameIdx)")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(Palette.textDim)
                        .shadow(color: .black.opacity(0.6), radius: 2, x: 0, y: 1)
                }
            }
        }
    }

    // MARK: - Bottom row: pos / lap / speed

    private var bottomRow: some View {
        HStack(alignment: .bottom, spacing: 14) {
            stat(label: "POS", value: posString, color: posColor)
            stat(label: "LAP", value: lapString)
            Spacer()
            stat(label: "SPEED", value: speedString, suffix: "MPH")
            if frame?.inPit == true {
                pitChip
            }
        }
    }

    private func stat(
        label: String,
        value: String,
        suffix: String? = nil,
        color: Color = Palette.textPrimary
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(1.5)
                .foregroundColor(Palette.textDim)
                .shadow(color: .black.opacity(0.6), radius: 2, x: 0, y: 1)
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 22, weight: .black, design: .monospaced))
                    .foregroundColor(color)
                    .shadow(color: .black.opacity(0.6), radius: 2, x: 0, y: 1)
                if let suffix {
                    Text(suffix)
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(Palette.textDim)
                        .shadow(color: .black.opacity(0.6), radius: 2, x: 0, y: 1)
                }
            }
        }
    }

    private var pitChip: some View {
        Text("PIT")
            .font(.system(size: 10, weight: .black, design: .monospaced))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(Palette.warning))
    }

    // MARK: - Formatting

    private var posString: String {
        guard let pos = frame?.pos, pos > 0 else { return "—" }
        if let total = frame?.totalCars, total > 0 {
            return "\(pos)/\(total)"
        }
        return "\(pos)"
    }

    private var posColor: Color {
        guard let pos = frame?.pos else { return Palette.textPrimary }
        if pos == 1 { return .yellow }
        if pos <= 3 { return Palette.brand }
        return Palette.textPrimary
    }

    private var lapString: String {
        guard let lap = frame?.lap, lap > 0 else { return "—" }
        return "\(lap)"
    }

    private var speedString: String {
        guard let speed = frame?.speed else { return "—" }
        return String(format: "%.0f", max(0, speed))
    }

    private func formatTime(_ seconds: Double) -> String {
        let secs = max(0, Int(seconds))
        let h = secs / 3600
        let m = (secs % 3600) / 60
        let s = secs % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }
}
