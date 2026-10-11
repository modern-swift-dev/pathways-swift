import Foundation

extension ISO8601DateFormatter {
    private static let pathwayFormatter = LockedPathwayDateFormatter()

    static func pathwayString(from date: Date) -> String {
        pathwayFormatter.string(from: date)
    }

    static func pathwayDate(from string: String) -> Date? {
        pathwayFormatter.date(from: string)
    }
}

/// The formatter never escapes, and every use is protected by the lock.
private final class LockedPathwayDateFormatter: @unchecked Sendable {
    private let lock = NSLock()
    private let formatter = makeFormatter([.withInternetDateTime, .withTimeZone])
    private let fractionalFormatter = makeFormatter([.withInternetDateTime, .withTimeZone, .withFractionalSeconds])

    private static func makeFormatter(_ options: ISO8601DateFormatter.Options) -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = .gmt
        formatter.formatOptions = options
        return formatter
    }

    /// Whole seconds keep the short form; other dates keep milliseconds.
    func string(from date: Date) -> String {
        let hasFraction = date.timeIntervalSince1970.rounded(.down) != date.timeIntervalSince1970
        return lock.withLock { (hasFraction ? fractionalFormatter : formatter).string(from: date) }
    }

    func date(from string: String) -> Date? {
        lock.withLock { formatter.date(from: string) ?? fractionalFormatter.date(from: string) }
    }
}
