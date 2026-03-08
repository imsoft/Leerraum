import Foundation
import OSLog

enum Observability {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "brangarciaramos.Leerraum"

    static let appLogger = Logger(subsystem: subsystem, category: "app")
    static let appSignposter = OSSignposter(subsystem: subsystem, category: "app")

    static let navigationLogger = Logger(subsystem: subsystem, category: "navigation")
    static let navigationSignposter = OSSignposter(subsystem: subsystem, category: "navigation")

    static let notificationsLogger = Logger(subsystem: subsystem, category: "notifications")
    static let notificationSignposter = OSSignposter(subsystem: subsystem, category: "notifications")

    static let financeLogger = Logger(subsystem: subsystem, category: "finance")
    static let financeSignposter = OSSignposter(subsystem: subsystem, category: "finance")

    static let gymLogger = Logger(subsystem: subsystem, category: "gym")
    static let gymSignposter = OSSignposter(subsystem: subsystem, category: "gym")

    static let foodLogger = Logger(subsystem: subsystem, category: "food")
    static let foodSignposter = OSSignposter(subsystem: subsystem, category: "food")

    static let bodyLogger = Logger(subsystem: subsystem, category: "body")
    static let bodySignposter = OSSignposter(subsystem: subsystem, category: "body")

    static let recommendationsLogger = Logger(subsystem: subsystem, category: "recommendations")
    static let recommendationsSignposter = OSSignposter(subsystem: subsystem, category: "recommendations")

    static func debug(_ logger: Logger, _ message: String) {
#if DEBUG
        logger.debug("\(message, privacy: .public)")
#endif
    }
}
