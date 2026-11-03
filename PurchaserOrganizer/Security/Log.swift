import OSLog

/// Unified logging. Anything that could identify a purchase (merchant, amount)
/// must be interpolated with `privacy: .private` so it is redacted in logs
/// collected from the device (sysdiagnose, Console.app).
enum Log {
    static let subsystem = Bundle.main.bundleIdentifier ?? "PurchaserOrganizer"
    static let ingest = Logger(subsystem: subsystem, category: "ingest")
    static let sync = Logger(subsystem: subsystem, category: "sync")
    static let security = Logger(subsystem: subsystem, category: "security")
}
