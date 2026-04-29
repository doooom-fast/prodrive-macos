import Foundation

/// One row from the telemetry JSONL stream. Field names match the
/// short-form schema produced by `prodrive-overlay/modules/js/telemetry-sidecar.js`.
/// We only decode the fields we paint in the editor's HUD — adding more is a
/// matter of declaring them here and updating `TelemetryOverlay`.
struct TelemetryFrame: Codable, Equatable {
    let t: Double           // seconds since session start
    let frame: Int?
    let pos: Int?
    let totalCars: Int?
    let lap: Int?
    let speed: Double?
    let incidents: Int?
    let inPit: Bool?

    enum CodingKeys: String, CodingKey {
        case t, frame, pos, totalCars, lap, speed, incidents, inPit
    }
}

/// Sorted array of telemetry frames keyed by `t`, with a binary-search
/// lookup. Build once on bundle open; the editor calls `frame(at:)` on
/// every player tick.
struct TelemetryIndex {

    let frames: [TelemetryFrame]
    let summary: SummaryRow?

    /// Markers (incidents, lap completions, pit events) for the timeline.
    let markers: [TelemetryMarker]

    /// Decode a JSONL stream into a frame index. Skips header + summary
    /// rows (those carry `_type`) and surfaces them as side fields.
    /// Frame parse errors are swallowed individually — one corrupted line
    /// shouldn't kill the whole index.
    static func decode(jsonl: Data) -> TelemetryIndex {
        guard let text = String(data: jsonl, encoding: .utf8) else {
            return TelemetryIndex(frames: [], summary: nil, markers: [])
        }
        var frames: [TelemetryFrame] = []
        var markers: [TelemetryMarker] = []
        var summary: SummaryRow?
        let decoder = JSONDecoder()
        // The JSONL stream isn't huge but reserving capacity avoids growth.
        frames.reserveCapacity(8192)

        text.enumerateLines { line, _ in
            guard !line.isEmpty,
                  let lineData = line.data(using: .utf8) else { return }

            if line.contains("\"_type\"") {
                if let kind = try? decoder.decode(TypedRow.self, from: lineData) {
                    switch kind._type {
                    case "summary":
                        if let s = try? decoder.decode(SummaryRow.self, from: lineData) {
                            summary = s
                            markers.append(contentsOf: s.markers ?? [])
                        }
                    default:
                        break
                    }
                }
                return
            }

            if let f = try? decoder.decode(TelemetryFrame.self, from: lineData) {
                frames.append(f)
            }
        }

        // Defensive sort — if the writer ever emits out-of-order frames the
        // binary search assumption breaks silently.
        frames.sort { $0.t < $1.t }
        return TelemetryIndex(frames: frames, summary: summary, markers: markers)
    }

    /// Frame whose `t` is closest to (and not past) `playheadSeconds`.
    /// Returns nil if the index is empty or the playhead is before the
    /// first frame.
    func frame(at playheadSeconds: Double) -> TelemetryFrame? {
        guard !frames.isEmpty else { return nil }
        if playheadSeconds <= frames[0].t { return frames[0] }
        if playheadSeconds >= frames[frames.count - 1].t { return frames[frames.count - 1] }

        var lo = 0
        var hi = frames.count - 1
        while lo + 1 < hi {
            let mid = (lo + hi) / 2
            if frames[mid].t <= playheadSeconds {
                lo = mid
            } else {
                hi = mid
            }
        }
        return frames[lo]
    }
}

struct TypedRow: Codable {
    let _type: String
}

struct SummaryRow: Codable {
    let _type: String
    let frames: Int?
    let durationMs: Double?
    let markers: [TelemetryMarker]?
}

/// Event marker emitted by the overlay's sidecar writer. The editor
/// surfaces these as ticks on the scrub bar (incidents in red, laps
/// in white, pit events in amber).
struct TelemetryMarker: Codable, Equatable, Identifiable {
    let type: String
    let frame: Int?
    let t: Double         // ms (matches the writer)
    let from: Int?
    let to: Int?
    let direction: String?
    let lap: Int?

    var id: String { "\(type)-\(t)-\(frame ?? -1)" }

    /// Convenient seconds value — the writer stores `t` as ms.
    var seconds: Double { t / 1000.0 }
}
