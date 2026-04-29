import Foundation
import Network

/// Minimal HTTP/1.1 server that accepts `POST /v1/bundles` from a paired
/// Windows app over the LAN. Body is the raw `.rcpdv` bytes; headers
/// carry the bundle id, timestamp, and HMAC signature.
///
/// Bytes stream straight to a temp file and are atomically renamed into
/// the library directory. The response is a tiny JSON status object.
///
/// This is intentionally a tiny hand-rolled server. We only support one
/// route, content-length framed bodies, and don't do TLS (LAN-only).
/// If the surface ever grows beyond two endpoints, replace with NIO/Vapor.
final class ReceiverServer {

    enum ReceiverError: Error, LocalizedError {
        case alreadyRunning
        case listenerFailed(String)

        var errorDescription: String? {
            switch self {
            case .alreadyRunning:           return "Receiver already running"
            case .listenerFailed(let why):  return "Listener failed: \(why)"
            }
        }
    }

    /// Notification posted on the main queue after a bundle is fully
    /// received and renamed into place. The `userInfo` carries `path`.
    static let bundleReceivedNotification = Notification.Name("ProDrive.bundleReceived")

    private let queue = DispatchQueue(label: "io.racecor.prodrive.receiver", qos: .userInitiated)

    private var listener: NWListener?
    private var sharedKeyProvider: () -> Data?
    private let saveDirectory: URL

    init(
        saveDirectory: URL,
        sharedKeyProvider: @escaping () -> Data?
    ) {
        self.saveDirectory = saveDirectory
        self.sharedKeyProvider = sharedKeyProvider
    }

    /// Starts the listener on the registered Prodrive port and advertises
    /// `_prodrive._tcp` via Bonjour with the supplied TXT records.
    func start(serviceName: String, txtRecords: [String: String]) throws {
        if listener != nil { throw ReceiverError.alreadyRunning }

        try? FileManager.default.createDirectory(
            at: saveDirectory, withIntermediateDirectories: true
        )

        let parameters = NWParameters.tcp
        // Picked from IANA's user-port range. If you change this, update
        // the C# discovery side and the bundle-transfer skill.
        let port = NWEndpoint.Port(rawValue: 50403)!
        let l = try NWListener(using: parameters, on: port)

        // NWTXTRecord accepts [String: String] directly — DNS-SD restricts
        // values to printable ASCII so we don't bother UTF-8 encoding.
        let txtData = NWTXTRecord(txtRecords).data
        l.service = NWListener.Service(
            name: serviceName,
            type: "_prodrive._tcp",
            txtRecord: txtData
        )

        l.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                Log.info("[Receiver] listening on :\(port)")
            case .failed(let error):
                Log.error("[Receiver] listener failed: \(error)")
                self?.stop()
            default: break
            }
        }
        l.newConnectionHandler = { [weak self] connection in
            guard let self else {
                connection.cancel()
                return
            }
            self.handle(connection: connection)
        }
        l.start(queue: queue)
        listener = l
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    // MARK: - Connection handling

    private func handle(connection: NWConnection) {
        let session = ReceiverSession(
            connection: connection,
            saveDirectory: saveDirectory,
            sharedKeyProvider: sharedKeyProvider,
            queue: queue
        )
        session.run()
    }
}

// MARK: - Per-connection state machine

private final class ReceiverSession {

    private let connection: NWConnection
    private let saveDirectory: URL
    private let sharedKeyProvider: () -> Data?
    private let queue: DispatchQueue

    private var headerBuffer = Data()
    private var headersParsed = false

    private var requestMethod = ""
    private var requestPath = ""
    private var contentLength: Int = 0
    private var bundleId = ""
    private var timestampMs: Int64 = 0
    private var signature = ""
    private var sender = ""

    private var tempFileHandle: FileHandle?
    private var tempFileURL: URL?
    private var bytesWrittenToBody: Int = 0

    init(
        connection: NWConnection,
        saveDirectory: URL,
        sharedKeyProvider: @escaping () -> Data?,
        queue: DispatchQueue
    ) {
        self.connection = connection
        self.saveDirectory = saveDirectory
        self.sharedKeyProvider = sharedKeyProvider
        self.queue = queue
    }

    func run() {
        connection.start(queue: queue)
        receive()
    }

    private func receive() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let error = error {
                Log.error("[Receiver] receive error: \(error)")
                self.connection.cancel()
                return
            }
            if let data = data, !data.isEmpty {
                self.consume(data: data)
            }
            if isComplete {
                self.finishOrFail()
                return
            }
            // Keep reading until content-length is satisfied OR the peer closes.
            if !self.bodyComplete {
                self.receive()
            } else {
                self.finishOrFail()
            }
        }
    }

    private var bodyComplete: Bool {
        headersParsed && bytesWrittenToBody >= contentLength
    }

    private func consume(data: Data) {
        if !headersParsed {
            headerBuffer.append(data)
            // Look for end-of-headers (CRLFCRLF) — bound the search to a
            // generous limit so a malformed peer can't grow the buffer.
            if headerBuffer.count > 32 * 1024 {
                respond(status: 431, message: "Request Header Fields Too Large")
                return
            }
            guard let separator = "\r\n\r\n".data(using: .ascii),
                  let range = headerBuffer.range(of: separator) else {
                return
            }
            let headerBytes = headerBuffer.subdata(in: 0..<range.lowerBound)
            let bodyStart = range.upperBound
            guard parseHeaders(headerBytes) else {
                respond(status: 400, message: "Bad Request")
                return
            }
            headersParsed = true

            // Auth + open temp file before consuming any body.
            guard validateAuth() else {
                respond(status: 401, message: "Unauthorized")
                return
            }
            guard openTempFile() else {
                respond(status: 500, message: "Server Error")
                return
            }

            // Any bytes that arrived past the header separator are body bytes.
            let leftover = headerBuffer.subdata(in: bodyStart..<headerBuffer.count)
            if !leftover.isEmpty { writeBody(leftover) }
            headerBuffer = Data()
            return
        }
        writeBody(data)
    }

    private func writeBody(_ chunk: Data) {
        guard let handle = tempFileHandle else { return }
        do {
            try handle.write(contentsOf: chunk)
            bytesWrittenToBody += chunk.count
        } catch {
            Log.error("[Receiver] write failed: \(error)")
            respond(status: 500, message: "Disk Write Failed")
        }
    }

    // MARK: - Header parsing

    private func parseHeaders(_ bytes: Data) -> Bool {
        guard let text = String(data: bytes, encoding: .utf8) else { return false }
        let lines = text.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else { return false }
        let parts = requestLine.split(separator: " ").map(String.init)
        guard parts.count >= 2 else { return false }
        requestMethod = parts[0]
        requestPath = parts[1]

        guard requestMethod.uppercased() == "POST",
              requestPath == "/v1/bundles" else {
            return false
        }

        for line in lines.dropFirst() {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let name = line[..<colon].lowercased().trimmingCharacters(in: .whitespaces)
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            switch name {
            case "content-length":      contentLength = Int(value) ?? 0
            case "x-prodrive-bundle-id": bundleId = value
            case "x-prodrive-timestamp": timestampMs = Int64(value) ?? 0
            case "x-prodrive-auth":     signature = value
            case "x-prodrive-sender":   sender = value
            default: break
            }
        }
        // Sanity bounds — refuse impossibly large or impossibly small bodies.
        if contentLength <= 24 || contentLength > 64 * 1024 * 1024 * 1024 {
            return false
        }
        return !bundleId.isEmpty && !signature.isEmpty && timestampMs > 0
    }

    private func validateAuth() -> Bool {
        guard let key = sharedKeyProvider(), !key.isEmpty else { return false }
        return SharedKey.verify(
            bundleId: bundleId,
            timestamp: timestampMs,
            signature: signature,
            key: key
        )
    }

    // MARK: - File I/O

    private func openTempFile() -> Bool {
        let tmpDir = saveDirectory.appendingPathComponent(".tmp", isDirectory: true)
        try? FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        let url = tmpDir.appendingPathComponent("\(bundleId)-\(UUID().uuidString).rcpdv")
        FileManager.default.createFile(atPath: url.path, contents: nil)
        guard let handle = try? FileHandle(forWritingTo: url) else { return false }
        tempFileURL = url
        tempFileHandle = handle
        return true
    }

    private func finalizeFile() -> URL? {
        guard let handle = tempFileHandle, let tmpURL = tempFileURL else { return nil }
        try? handle.synchronize()
        try? handle.close()
        let finalURL = saveDirectory.appendingPathComponent("\(bundleId).rcpdv")
        do {
            try? FileManager.default.removeItem(at: finalURL)
            try FileManager.default.moveItem(at: tmpURL, to: finalURL)
            return finalURL
        } catch {
            Log.error("[Receiver] finalize failed: \(error)")
            return nil
        }
    }

    // MARK: - Response

    private func finishOrFail() {
        if !headersParsed {
            respond(status: 400, message: "Empty Request")
            return
        }
        if bytesWrittenToBody < contentLength {
            respond(status: 400, message: "Truncated Body")
            cleanupTemp()
            return
        }
        guard let savedTo = finalizeFile() else {
            respond(status: 500, message: "Could Not Save")
            return
        }
        let json = """
        {"received":true,"bundleId":"\(bundleId)","savedAt":"\(savedTo.path)"}
        """
        respond(status: 202, message: "Accepted", body: json)

        // Notify the library on the main queue so the view model picks it up.
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: ReceiverServer.bundleReceivedNotification,
                object: nil,
                userInfo: ["path": savedTo.path, "bundleId": self.bundleId]
            )
        }
    }

    private func respond(status: Int, message: String, body: String = "") {
        let bodyData = body.data(using: .utf8) ?? Data()
        let head = """
        HTTP/1.1 \(status) \(message)\r
        Content-Type: application/json; charset=utf-8\r
        Content-Length: \(bodyData.count)\r
        Connection: close\r
        \r

        """
        var payload = Data(head.utf8)
        payload.append(bodyData)
        connection.send(content: payload, completion: .contentProcessed { [weak self] _ in
            self?.connection.cancel()
            self?.cleanupTemp()
        })
    }

    private func cleanupTemp() {
        if let url = tempFileURL {
            try? FileManager.default.removeItem(at: url)
        }
        tempFileHandle = nil
        tempFileURL = nil
    }
}
