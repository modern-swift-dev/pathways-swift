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
    private let formatter: ISO8601DateFormatter

    init() {
        formatter = ISO8601DateFormatter()
        formatter.timeZone = .gmt
        formatter.formatOptions = [.withInternetDateTime, .withTimeZone]
    }

    func string(from date: Date) -> String {
        lock.withLock { formatter.string(from: date) }
    }

    func date(from string: String) -> Date? {
        lock.withLock { formatter.date(from: string) }
    }
}
