import Foundation
import os.log

struct Log {
    private static let logger = os.Logger(subsystem: "racing.k10motorsports.prodrive.racecor.mac", category: "app")

    static func info(_ message: String) {
        logger.info("\(message)")
    }

    static func error(_ message: String) {
        logger.error("\(message)")
    }

    static func debug(_ message: String) {
        logger.debug("\(message)")
    }
}
