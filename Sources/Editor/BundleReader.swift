import Foundation
import Compression

/// Reader for the `.rcpdv` portable bundle format.
///
/// Mirrors the byte layout produced by `prodrive-overlay/modules/js/bundle-writer.js`.
/// The bundle is an ISO-BMFF MP4 with a private `uuid` box at any top-level
/// position; the box payload is `[headerLen:4 BE][headerJSON][gzip(JSONL)]`.
///
/// Spec: agents/skills/race-bundle-format/SKILL.md
enum BundleReader {

    /// 16-byte UUID identifying our private box. First 12 bytes spell
    /// `PRODRIVETLMY` in ASCII; last 4 bytes are the box format version.
    static let prodriveTelemetryUUID: [UInt8] = [
        0x50, 0x52, 0x4F, 0x44, 0x52, 0x49, 0x56, 0x45, // PRODRIVE
        0x54, 0x4C, 0x4D, 0x59,                         // TLMY
        0x00, 0x00,                                     // reserved
        0x00, 0x01,                                     // box format version
    ]

    enum ReadError: Error, LocalizedError {
        case fileNotFound
        case ioFailed(String)
        case notAProDriveBundle
        case malformedBundle(String)
        case decodeFailed(String)

        var errorDescription: String? {
            switch self {
            case .fileNotFound: return "Bundle file not found"
            case .ioFailed(let why): return "I/O error: \(why)"
            case .notAProDriveBundle: return "Not a Pro Drive bundle (missing telemetry box)"
            case .malformedBundle(let why): return "Malformed bundle: \(why)"
            case .decodeFailed(let why): return "Decode failed: \(why)"
            }
        }
    }

    // MARK: - Header (cheap)

    /// Read just the bundle header without decompressing telemetry.
    /// Cost: a handful of small reads — appropriate to call from a library
    /// scanner that displays metadata for hundreds of bundles.
    static func readHeader(at url: URL) throws -> BundleHeader {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ReadError.fileNotFound
        }
        let handle: FileHandle
        do { handle = try FileHandle(forReadingFrom: url) }
        catch { throw ReadError.ioFailed("\(error)") }
        defer { try? handle.close() }

        let totalSize: UInt64
        do { totalSize = try handle.seekToEnd() }
        catch { throw ReadError.ioFailed("seekToEnd: \(error)") }

        guard let payloadOffset = try findTelemetryBoxPayloadOffset(handle: handle, totalSize: totalSize) else {
            throw ReadError.notAProDriveBundle
        }

        // Read 4-byte big-endian header length.
        try handle.seek(toOffset: payloadOffset)
        let lenBytes = handle.readData(ofLength: 4)
        guard lenBytes.count == 4 else {
            throw ReadError.malformedBundle("truncated header length")
        }
        let headerLen = UInt32(bigEndianBytes: [UInt8](lenBytes))

        let headerJsonBytes = handle.readData(ofLength: Int(headerLen))
        guard headerJsonBytes.count == Int(headerLen) else {
            throw ReadError.malformedBundle("truncated header JSON")
        }

        do {
            let decoder = JSONDecoder()
            // ISO 8601 with optional fractional seconds — match server convention.
            decoder.dateDecodingStrategy = .iso8601WithFractionalSeconds
            return try decoder.decode(BundleHeader.self, from: headerJsonBytes)
        } catch {
            throw ReadError.decodeFailed("\(error)")
        }
    }

    // MARK: - Telemetry (decompresses)

    /// Read the full JSONL telemetry stream. Decompresses gzip in-process.
    /// Cost: proportional to telemetry size; for hour-long sessions this can be
    /// 10-50 MB decompressed. Call lazily — never on a library scan.
    static func readTelemetry(at url: URL) throws -> Data {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ReadError.fileNotFound
        }
        let handle: FileHandle
        do { handle = try FileHandle(forReadingFrom: url) }
        catch { throw ReadError.ioFailed("\(error)") }
        defer { try? handle.close() }

        let totalSize: UInt64
        do { totalSize = try handle.seekToEnd() }
        catch { throw ReadError.ioFailed("seekToEnd: \(error)") }

        guard let payloadOffset = try findTelemetryBoxPayloadOffset(handle: handle, totalSize: totalSize),
              let boxEnd = try findTelemetryBoxEnd(handle: handle, totalSize: totalSize) else {
            throw ReadError.notAProDriveBundle
        }

        try handle.seek(toOffset: payloadOffset)
        let lenBytes = handle.readData(ofLength: 4)
        guard lenBytes.count == 4 else {
            throw ReadError.malformedBundle("truncated header length")
        }
        let headerLen = UInt32(bigEndianBytes: [UInt8](lenBytes))

        let compressedStart = payloadOffset + 4 + UInt64(headerLen)
        guard compressedStart < boxEnd else {
            throw ReadError.malformedBundle("header overflows box")
        }
        let compressedLength = Int(boxEnd - compressedStart)

        try handle.seek(toOffset: compressedStart)
        let compressed = handle.readData(ofLength: compressedLength)
        guard compressed.count == compressedLength else {
            throw ReadError.malformedBundle("truncated telemetry")
        }

        guard let decompressed = gunzip(compressed) else {
            throw ReadError.decodeFailed("gunzip failed")
        }
        return decompressed
    }

    // MARK: - Box walking

    /// Walk top-level boxes until we find the one whose UUID matches ours,
    /// returning the offset to the start of the *payload* (i.e. just past
    /// the 16-byte UUID, where `[headerLen][headerJSON][gzip]` begins).
    private static func findTelemetryBoxPayloadOffset(
        handle: FileHandle, totalSize: UInt64
    ) throws -> UInt64? {
        var offset: UInt64 = 0
        while offset + 8 <= totalSize {
            try handle.seek(toOffset: offset)
            let head = handle.readData(ofLength: 8)
            guard head.count == 8 else { return nil }
            let size = UInt32(bigEndianBytes: [UInt8](head[0..<4]))
            let type = String(data: head[4..<8], encoding: .ascii) ?? ""

            if type == "uuid" && size >= 24 {
                try handle.seek(toOffset: offset + 8)
                let uuid = handle.readData(ofLength: 16)
                if [UInt8](uuid) == prodriveTelemetryUUID {
                    return offset + 8 + 16
                }
            }

            // Advance to the next top-level box.
            if size == 0 {
                // size=0 means "extends to EOF" — we're at the last box.
                return nil
            } else if size == 1 {
                // 64-bit largesize follows the 8-byte head.
                try handle.seek(toOffset: offset + 8)
                let large = handle.readData(ofLength: 8)
                guard large.count == 8 else { return nil }
                let largeSize = UInt64(bigEndianBytes: [UInt8](large))
                offset += largeSize
            } else {
                offset += UInt64(size)
            }
        }
        return nil
    }

    /// Find the byte-offset just past the end of our telemetry box.
    /// Used to bound the gzipped payload read.
    private static func findTelemetryBoxEnd(
        handle: FileHandle, totalSize: UInt64
    ) throws -> UInt64? {
        var offset: UInt64 = 0
        while offset + 8 <= totalSize {
            try handle.seek(toOffset: offset)
            let head = handle.readData(ofLength: 8)
            guard head.count == 8 else { return nil }
            let size = UInt32(bigEndianBytes: [UInt8](head[0..<4]))
            let type = String(data: head[4..<8], encoding: .ascii) ?? ""

            // Determine the actual size of *this* box (handling the largesize escape).
            let boxBytes: UInt64
            if size == 0 {
                boxBytes = totalSize - offset
            } else if size == 1 {
                try handle.seek(toOffset: offset + 8)
                let large = handle.readData(ofLength: 8)
                guard large.count == 8 else { return nil }
                boxBytes = UInt64(bigEndianBytes: [UInt8](large))
            } else {
                boxBytes = UInt64(size)
            }

            if type == "uuid" && boxBytes >= 24 {
                try handle.seek(toOffset: offset + 8)
                let uuid = handle.readData(ofLength: 16)
                if [UInt8](uuid) == prodriveTelemetryUUID {
                    return offset + boxBytes
                }
            }

            offset += boxBytes
        }
        return nil
    }

    // MARK: - gunzip via Compression framework

    /// Decompress a gzip stream. Apple's `Compression` framework supports
    /// raw deflate via `COMPRESSION_ZLIB`, which expects a 2-byte zlib header
    /// (CMF+FLG) — NOT the 10-byte gzip header we have here. So we strip the
    /// gzip envelope manually and feed the deflate payload to the framework.
    private static func gunzip(_ data: Data) -> Data? {
        // Minimum gzip stream: 10-byte header + 8-byte trailer + at least 2 bytes deflate.
        guard data.count > 18 else { return nil }
        let bytes = [UInt8](data)
        // Magic: 0x1F 0x8B — gzip identifier.
        guard bytes[0] == 0x1F, bytes[1] == 0x8B else { return nil }
        guard bytes[2] == 0x08 else { return nil } // compression method: deflate

        let flg = bytes[3]
        var headerEnd = 10
        // FEXTRA
        if flg & 0x04 != 0 {
            guard bytes.count >= headerEnd + 2 else { return nil }
            let xlen = Int(bytes[headerEnd]) | (Int(bytes[headerEnd + 1]) << 8)
            headerEnd += 2 + xlen
        }
        // FNAME — null-terminated string
        if flg & 0x08 != 0 {
            while headerEnd < bytes.count && bytes[headerEnd] != 0 { headerEnd += 1 }
            headerEnd += 1
        }
        // FCOMMENT — null-terminated string
        if flg & 0x10 != 0 {
            while headerEnd < bytes.count && bytes[headerEnd] != 0 { headerEnd += 1 }
            headerEnd += 1
        }
        // FHCRC — 2 bytes
        if flg & 0x02 != 0 { headerEnd += 2 }

        let trailerLen = 8 // 4 bytes CRC32 + 4 bytes ISIZE
        guard headerEnd + trailerLen <= bytes.count else { return nil }
        let deflateStart = headerEnd
        let deflateEnd = bytes.count - trailerLen
        let deflatePayload = data.subdata(in: deflateStart..<deflateEnd)

        // Read uncompressed size from the gzip ISIZE field (little-endian).
        let isizeOffset = bytes.count - 4
        let isize =
            UInt32(bytes[isizeOffset]) |
            (UInt32(bytes[isizeOffset + 1]) << 8) |
            (UInt32(bytes[isizeOffset + 2]) << 16) |
            (UInt32(bytes[isizeOffset + 3]) << 24)

        // Allocate a destination ~uncompressed size; if ISIZE is bogus, fall back to 4× compressed.
        let estimatedSize = isize > 0 ? Int(isize) : deflatePayload.count * 4
        var dst = Data(count: estimatedSize)

        let decoded = dst.withUnsafeMutableBytes { (dstPtr: UnsafeMutableRawBufferPointer) -> Int in
            deflatePayload.withUnsafeBytes { (srcPtr: UnsafeRawBufferPointer) -> Int in
                guard let dstBase = dstPtr.bindMemory(to: UInt8.self).baseAddress,
                      let srcBase = srcPtr.bindMemory(to: UInt8.self).baseAddress else {
                    return 0
                }
                return compression_decode_buffer(
                    dstBase, estimatedSize,
                    srcBase, deflatePayload.count,
                    nil, COMPRESSION_ZLIB
                )
            }
        }
        guard decoded > 0 else { return nil }
        dst.count = decoded
        return dst
    }
}

// MARK: - BundleHeader

/// Decoded form of the JSON header inside a `.rcpdv` `uuid` box.
///
/// Keep every field that round-trips through the editor declared here —
/// missing fields get silently dropped on re-encode (see the JSON round-trip
/// strip trap documented in `web-to-native-migration` skill).
struct BundleHeader: Codable, Equatable {
    let schemaVersion: Int
    let bundleId: String
    let createdAt: Date
    let startedAt: Date?
    let createdBy: CreatedBy
    let race: Race
    let video: Video
    let telemetry: Telemetry

    struct CreatedBy: Codable, Equatable {
        let app: String
        let version: String?
        let platform: String?
    }

    struct Race: Codable, Equatable {
        let title: String?
        let track: String?
        let car: String?
        let series: String?
        let sessionType: String?
        let sessionId: String?
        let gameId: String?
        let isDemo: Bool?
        let userId: String?
    }

    struct Video: Codable, Equatable {
        let duration: Double
        let frameRate: Double
        let width: Int
        let height: Int
        let codec: String
    }

    struct Telemetry: Codable, Equatable {
        let frameCount: Int
        let frameRate: Double
        let schema: String
        let compressedBytes: Int
        let uncompressedBytes: Int
        let hasSummary: Bool?
    }
}

// MARK: - Helpers

private extension UInt32 {
    init(bigEndianBytes bytes: [UInt8]) {
        precondition(bytes.count >= 4)
        self =
            (UInt32(bytes[0]) << 24) |
            (UInt32(bytes[1]) << 16) |
            (UInt32(bytes[2]) << 8) |
             UInt32(bytes[3])
    }
}

private extension UInt64 {
    init(bigEndianBytes bytes: [UInt8]) {
        precondition(bytes.count >= 8)
        self =
            (UInt64(bytes[0]) << 56) |
            (UInt64(bytes[1]) << 48) |
            (UInt64(bytes[2]) << 40) |
            (UInt64(bytes[3]) << 32) |
            (UInt64(bytes[4]) << 24) |
            (UInt64(bytes[5]) << 16) |
            (UInt64(bytes[6]) << 8) |
             UInt64(bytes[7])
    }
}

private extension JSONDecoder.DateDecodingStrategy {
    static var iso8601WithFractionalSeconds: JSONDecoder.DateDecodingStrategy {
        .custom { decoder in
            let str = try decoder.singleValueContainer().decode(String.self)
            let withFrac = ISO8601DateFormatter()
            withFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let d = withFrac.date(from: str) { return d }
            let plain = ISO8601DateFormatter()
            plain.formatOptions = [.withInternetDateTime]
            if let d = plain.date(from: str) { return d }
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Invalid ISO 8601 date: \(str)"
                )
            )
        }
    }
}
