import Foundation
import Combine

/// Scans well-known folders for `.rcpdv` bundles and exposes the parsed
/// header for each one to the library view. Read-only — sharing /
/// receiving / deletion happen elsewhere.
///
/// Locations scanned (first hit wins for dedup by bundleId):
///   1. `~/Documents/RaceCor/sessions/` — canonical home for transferred bundles
///   2. `~/Movies/`                     — overlay records here on macOS
///   3. `~/Videos/`                     — fallback for bundles dragged from Windows
///
/// Header reads are cached in-memory keyed by file path + mtime. Re-scans
/// are explicit (call `refresh()`) — no FSEvents wiring yet; the editor
/// is single-window and refresh-on-show is enough.
@MainActor
final class LibraryViewModel: ObservableObject {

    @Published private(set) var entries: [LibraryEntry] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var lastError: String?

    /// In-memory cache of parsed headers by file path + mtime fingerprint.
    /// Avoids re-reading the uuid box every time the user toggles tabs.
    private var headerCache: [String: CacheEntry] = [:]

    private let scanLocations: [URL]

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        self.scanLocations = [
            home.appendingPathComponent("Documents/RaceCor/sessions", isDirectory: true),
            home.appendingPathComponent("Movies", isDirectory: true),
            home.appendingPathComponent("Videos", isDirectory: true),
        ]
    }

    /// Force a fresh scan. Files whose path + mtime fingerprint matches the
    /// cache reuse the cached header (no I/O); new or changed files get re-read.
    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        lastError = nil

        var found: [LibraryEntry] = []
        var seenBundleIds = Set<String>()

        for root in scanLocations {
            let urls = enumerate(root: root)
            for url in urls {
                let fingerprint = mtimeFingerprint(url: url)

                // Cache hit?
                if let cached = headerCache[url.path], cached.fingerprint == fingerprint {
                    if !seenBundleIds.contains(cached.entry.header.bundleId) {
                        found.append(cached.entry)
                        seenBundleIds.insert(cached.entry.header.bundleId)
                    }
                    continue
                }

                // Cache miss — read the header.
                do {
                    let header = try BundleReader.readHeader(at: url)
                    let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
                    let fileSize = (attrs?[.size] as? NSNumber)?.int64Value ?? 0
                    let fileMtime = (attrs?[.modificationDate] as? Date) ?? Date()
                    let entry = LibraryEntry(
                        url: url,
                        header: header,
                        fileSize: fileSize,
                        fileMtime: fileMtime
                    )
                    headerCache[url.path] = CacheEntry(fingerprint: fingerprint, entry: entry)
                    if !seenBundleIds.contains(header.bundleId) {
                        found.append(entry)
                        seenBundleIds.insert(header.bundleId)
                    }
                } catch BundleReader.ReadError.notAProDriveBundle {
                    // Quietly skip plain .rcpdv files that aren't ours.
                    continue
                } catch {
                    // Surface a *first* error, but keep scanning — one
                    // corrupt file shouldn't blank the whole library.
                    if lastError == nil {
                        lastError = "Couldn't read \(url.lastPathComponent): \(error.localizedDescription)"
                    }
                }
            }
        }

        // Most-recent-first by the header's createdAt (falls back to file mtime).
        found.sort { lhs, rhs in
            lhs.header.createdAt > rhs.header.createdAt
        }
        self.entries = found
    }

    // MARK: - Folder enumeration

    private func enumerate(root: URL) -> [URL] {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: root.path, isDirectory: &isDir), isDir.boolValue else {
            return []
        }
        let resourceKeys: [URLResourceKey] = [.isRegularFileKey, .nameKey]
        guard let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }

        var urls: [URL] = []
        for case let url as URL in enumerator {
            if url.pathExtension.lowercased() == "rcpdv" {
                urls.append(url)
            }
        }
        return urls
    }

    private func mtimeFingerprint(url: URL) -> String {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path) else {
            return "no-stat"
        }
        let size = (attrs[.size] as? NSNumber)?.int64Value ?? 0
        let mtime = (attrs[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
        return "\(size)-\(mtime)"
    }

    // MARK: - Cache shape

    private struct CacheEntry {
        let fingerprint: String
        let entry: LibraryEntry
    }
}

/// One row in the library — the file plus everything we know about it
/// from the cheap header read.
struct LibraryEntry: Identifiable, Equatable {
    let url: URL
    let header: BundleHeader
    let fileSize: Int64
    let fileMtime: Date

    var id: String { header.bundleId }

    /// Human-friendly title — falls back through race title → track + car → filename.
    var displayTitle: String {
        if let title = header.race.title, !title.isEmpty { return title }
        let track = header.race.track
        let car = header.race.car
        switch (track, car) {
        case let (t?, c?): return "\(t) — \(c)"
        case let (t?, nil): return t
        case let (nil, c?): return c
        default: return url.deletingPathExtension().lastPathComponent
        }
    }

    var displayDuration: String {
        let secs = max(0, header.video.duration)
        let h = Int(secs) / 3600
        let m = (Int(secs) % 3600) / 60
        let s = Int(secs) % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }

    var displayFileSize: String {
        let bytes = Double(fileSize)
        if bytes >= 1_000_000_000 {
            return String(format: "%.1f GB", bytes / 1_000_000_000)
        }
        return String(format: "%.0f MB", bytes / 1_000_000)
    }
}
