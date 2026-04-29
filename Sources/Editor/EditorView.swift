import SwiftUI
import AVFoundation

/// Editor surface for a single `.rcpdv` bundle. v1 (this PR) gives you:
/// 1. AVPlayer-backed video stage (the bytes are valid MP4)
/// 2. Telemetry HUD overlay synced to playback time
/// 3. Scrub bar with markers and play/pause/skip controls
/// 4. Detail panel with bundle metadata
///
/// Out of scope for this PR (lands as PR-7+):
/// - EDL editing (drag segments, reorder, delete)
/// - Claude director refine
/// - ffmpeg render → output.mp4
/// - YouTube upload
struct EditorView: View {
    let entry: LibraryEntry
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model: EditorViewModel

    init(entry: LibraryEntry) {
        self.entry = entry
        _model = StateObject(wrappedValue: EditorViewModel(entry: entry))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().background(Palette.borderSubtle)

            // Stage occupies as much vertical space as it can.
            stage
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            controls
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(Palette.bgPanel)
        }
        .background(Palette.bgBase.ignoresSafeArea())
        .onAppear { model.start() }
        .onDisappear { model.stop() }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Palette.textPrimary)
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Palette.bgElevated)
                    )
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.displayTitle)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Palette.textPrimary)
                Text(entry.url.lastPathComponent)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Palette.textDim)
            }

            Spacer()

            telemetryStatus
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(Palette.bgPanel)
    }

    @ViewBuilder
    private var telemetryStatus: some View {
        switch model.telemetryStatus {
        case .loading:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Loading telemetry…")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Palette.textDim)
            }
        case .ready(let frameCount):
            HStack(spacing: 4) {
                Image(systemName: "waveform")
                    .font(.system(size: 10))
                Text("\(frameCount.formatted()) frames")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
            }
            .foregroundColor(Palette.textDim)
        case .failed(let why):
            Text(why)
                .font(.system(size: 10))
                .foregroundColor(Palette.brand)
        }
    }

    // MARK: - Stage

    private var stage: some View {
        ZStack {
            Color.black

            if let player = model.player {
                AVPlayerLayerView(player: player)
            }

            TelemetryOverlay(
                header: entry.header,
                frame: model.currentFrame,
                playheadSeconds: model.playheadSeconds
            )
        }
        .clipped()
    }

    // MARK: - Controls

    private var controls: some View {
        VStack(spacing: 10) {
            scrubRow
            transportRow
        }
    }

    private var scrubRow: some View {
        HStack(spacing: 12) {
            Text(formatTime(model.playheadSeconds))
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(Palette.textPrimary)
                .frame(width: 56, alignment: .leading)

            ZStack(alignment: .leading) {
                ScrubSlider(
                    value: Binding(
                        get: { model.playheadSeconds },
                        set: { newValue in model.scrub(to: newValue) }
                    ),
                    range: 0...max(0.1, model.duration)
                )
                MarkerStrip(markers: model.markers, duration: model.duration)
                    .allowsHitTesting(false)
            }

            Text(formatTime(model.duration))
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(Palette.textDim)
                .frame(width: 56, alignment: .trailing)
        }
    }

    private var transportRow: some View {
        HStack(spacing: 14) {
            transportButton("gobackward.10") { model.skip(by: -10) }
            transportButton(model.isPlaying ? "pause.fill" : "play.fill", primary: true) {
                model.togglePlay()
            }
            transportButton("goforward.10") { model.skip(by: 10) }

            Spacer()

            Button(action: { model.toggleDetails() }) {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 11))
                    Text("Details")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(Palette.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Palette.bgElevated)
                )
            }
            .buttonStyle(.plain)
            .popover(isPresented: $model.showDetails, arrowEdge: .bottom) {
                detailsPopover
                    .frame(width: 360)
                    .padding(16)
            }
        }
    }

    private func transportButton(_ icon: String, primary: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: primary ? 16 : 13, weight: .bold))
                .foregroundColor(Palette.textPrimary)
                .frame(width: primary ? 40 : 32, height: primary ? 40 : 32)
                .background(
                    RoundedRectangle(cornerRadius: primary ? 20 : 8, style: .continuous)
                        .fill(primary ? Palette.brand : Palette.bgElevated)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Details popover

    @ViewBuilder
    private var detailsPopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Details")
                .font(.system(size: 11, weight: .bold))
                .tracking(1.5)
                .foregroundColor(Palette.textDim)

            detailRow("Track", entry.header.race.track)
            detailRow("Car", entry.header.race.car)
            detailRow("Duration", entry.displayDuration)
            detailRow("Resolution", "\(entry.header.video.width) × \(entry.header.video.height)")
            detailRow("File size", entry.displayFileSize)
            detailRow("Frames", entry.header.telemetry.frameCount.formatted())
            detailRow("Bundle ID", entry.header.bundleId)
            detailRow("Recorded by",
                "\(entry.header.createdBy.app) \(entry.header.createdBy.version ?? "")"
                    .trimmingCharacters(in: .whitespaces))
            detailRow("Created", DateFormatter.editor.string(from: entry.header.createdAt))
        }
    }

    @ViewBuilder
    private func detailRow(_ label: String, _ value: String?) -> some View {
        if let value, !value.isEmpty {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(label.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.2)
                    .foregroundColor(Palette.textMuted)
                    .frame(width: 90, alignment: .leading)
                Text(value)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(Palette.textPrimary)
                    .textSelection(.enabled)
            }
        }
    }

    // MARK: - Helpers

    private func formatTime(_ seconds: Double) -> String {
        let secs = max(0, Int(seconds))
        let h = secs / 3600
        let m = (secs % 3600) / 60
        let s = secs % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - View Model

@MainActor
final class EditorViewModel: ObservableObject {

    let entry: LibraryEntry

    @Published private(set) var player: AVPlayer?
    @Published private(set) var duration: Double = 0
    @Published private(set) var playheadSeconds: Double = 0
    @Published private(set) var isPlaying: Bool = false
    @Published private(set) var currentFrame: TelemetryFrame?
    @Published private(set) var markers: [TelemetryMarker] = []
    @Published private(set) var telemetryStatus: TelemetryStatus = .loading
    @Published var showDetails: Bool = false

    private var index: TelemetryIndex?
    private var timeObserverToken: Any?

    enum TelemetryStatus {
        case loading
        case ready(frameCount: Int)
        case failed(String)
    }

    init(entry: LibraryEntry) {
        self.entry = entry
    }

    func start() {
        // Build an AVPlayer immediately so video plays while telemetry decompresses.
        let asset = AVURLAsset(url: entry.url)
        let item = AVPlayerItem(asset: asset)
        let player = AVPlayer(playerItem: item)
        self.player = player

        Task { [weak self] in
            // Pull duration once the asset is loaded.
            do {
                let cmDuration = try await asset.load(.duration)
                let secs = CMTimeGetSeconds(cmDuration)
                if secs.isFinite {
                    await MainActor.run { self?.duration = secs }
                }
            } catch {
                // Use the bundle header's duration as a fallback.
                await MainActor.run { self?.duration = self?.entry.header.video.duration ?? 0 }
            }
        }

        // Periodic time observer for the HUD + scrub. 10Hz is plenty for
        // a HUD; AVPlayer rate-limits internally if you ask for too much.
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self else { return }
            let secs = CMTimeGetSeconds(time)
            if secs.isFinite {
                self.playheadSeconds = secs
                self.currentFrame = self.index?.frame(at: secs)
            }
        }

        // Decompress + parse telemetry off the main thread.
        Task { [weak self] in
            guard let self else { return }
            do {
                let jsonl = try BundleReader.readTelemetry(at: self.entry.url)
                let parsed = TelemetryIndex.decode(jsonl: jsonl)
                await MainActor.run {
                    self.index = parsed
                    self.markers = parsed.markers
                    self.telemetryStatus = .ready(frameCount: parsed.frames.count)
                    // Seed the HUD before the first time observer tick.
                    self.currentFrame = parsed.frame(at: self.playheadSeconds)
                }
            } catch {
                await MainActor.run {
                    self.telemetryStatus = .failed("Telemetry unavailable")
                }
            }
        }
    }

    func stop() {
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
            timeObserverToken = nil
        }
        player?.pause()
        player = nil
        isPlaying = false
    }

    func togglePlay() {
        guard let player else { return }
        if isPlaying {
            player.pause()
        } else {
            // Loop back to start if we're at the end.
            if duration > 0 && playheadSeconds >= duration - 0.25 {
                player.seek(to: .zero)
            }
            player.play()
        }
        isPlaying.toggle()
    }

    func skip(by seconds: Double) {
        guard let player else { return }
        let target = max(0, min(duration, playheadSeconds + seconds))
        let cm = CMTime(seconds: target, preferredTimescale: 600)
        player.seek(to: cm, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    func scrub(to seconds: Double) {
        guard let player else { return }
        let target = max(0, min(duration, seconds))
        let cm = CMTime(seconds: target, preferredTimescale: 600)
        // Lower precision while dragging is fine — the HUD and the visual
        // both update on the next time observer fire.
        player.seek(to: cm, toleranceBefore: .positiveInfinity, toleranceAfter: .positiveInfinity)
    }

    func toggleDetails() { showDetails.toggle() }
}

// MARK: - Scrub slider + marker strip

struct ScrubSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    @State private var isDragging = false

    var body: some View {
        GeometryReader { geo in
            let span = max(0.0001, range.upperBound - range.lowerBound)
            let position = CGFloat((value - range.lowerBound) / span) * geo.size.width
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Palette.bgElevated)
                    .frame(height: 4)
                Capsule()
                    .fill(Palette.brand)
                    .frame(width: max(0, position), height: 4)
                Circle()
                    .fill(Palette.textPrimary)
                    .frame(width: isDragging ? 14 : 10, height: isDragging ? 14 : 10)
                    .overlay(
                        Circle().stroke(Palette.brand, lineWidth: 2)
                    )
                    .offset(x: max(0, min(geo.size.width - 7, position - 5)))
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { dg in
                        isDragging = true
                        let pct = max(0, min(1, dg.location.x / geo.size.width))
                        value = range.lowerBound + Double(pct) * span
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
            .frame(height: 18)
        }
        .frame(height: 18)
    }
}

struct MarkerStrip: View {
    let markers: [TelemetryMarker]
    let duration: Double

    var body: some View {
        GeometryReader { geo in
            let span = max(0.0001, duration)
            ZStack(alignment: .leading) {
                ForEach(markers) { m in
                    let pct = CGFloat(min(1, max(0, m.seconds / span)))
                    Circle()
                        .fill(color(for: m))
                        .frame(width: 4, height: 4)
                        .offset(x: pct * geo.size.width - 2, y: 14)
                }
            }
        }
        .frame(height: 18)
    }

    private func color(for marker: TelemetryMarker) -> Color {
        switch marker.type {
        case "incident":         return Palette.brand
        case "new_lap":          return .white.opacity(0.9)
        case "pit_entry",
             "pit_exit":         return Palette.warning
        case "position_change":  return Palette.textDim
        default:                 return Palette.textMuted
        }
    }
}

// MARK: - Date formatter

private extension DateFormatter {
    static let editor: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()
}
