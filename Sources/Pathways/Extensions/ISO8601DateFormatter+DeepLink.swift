import Foundation

extension ISO8601DateFormatter {
    static var noFractionalSeconds: ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = .gmt
        formatter.formatOptions = [.withInternetDateTime, .withTimeZone]
        return formatter
    }
}
