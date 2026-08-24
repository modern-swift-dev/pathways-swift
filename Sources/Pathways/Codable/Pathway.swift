import Foundation

/// Supplies the URL path pattern used to encode or decode a deep link.
///
/// A pattern contains literal path components and placeholders prefixed with
/// `:`. Each placeholder name must match a Codable coding key on the adopting
/// type.
///
/// ```swift
/// static let pattern = "/products/:productID"
/// ```
public protocol PathwayPatternProvider: Sendable {

    /// The path pattern for the adopting type.
    ///
    /// Use a leading slash and name placeholders with the corresponding Codable
    /// coding keys, such as `/users/:id`.
    static var pattern: String { get }
}

/// A type that can be decoded from a URL path using ``PathwayDecoder``.
///
/// - Important: Pathways supports only flat Codable models. Nested keyed and
///   unkeyed containers are unsupported.
public protocol PathwayDecodable: Decodable, PathwayPatternProvider {}

/// A type that can be encoded as a URL path using ``PathwayEncoder``.
///
/// - Important: Pathways supports only flat Codable models. Nested keyed and
///   unkeyed containers are unsupported.
public protocol PathwayEncodable: Encodable, PathwayPatternProvider {}

/// A type that can both encode to and decode from a URL path.
///
/// Adopt this protocol for route models used with both ``PathwayEncoder`` and
/// ``PathwayDecoder``.
///
/// - Important: Pathways supports only flat Codable models. Nested keyed and
///   unkeyed containers are unsupported.
public protocol Pathway: PathwayDecodable, PathwayEncodable {}

extension PathwayPatternProvider {

    static var regex: NSRegularExpression? {
        regex(matching: .prefix)
    }

    static func regex(matching policy: PathwayMatchPolicy) -> NSRegularExpression? {
        var regex = "^"
        regex += NSRegularExpression.escapedPattern(for: "/")
        let components = pattern.split(separator: "/").map { String($0) }
        for (index, component) in components.enumerated() {
            if component.hasPrefix(":") {
                switch policy {
                    case .prefix:
                        regex += ".*"
                    case .exact:
                        regex += "[^/]+"
                }
            } else {
                switch policy {
                    case .prefix:
                        regex += component
                    case .exact:
                        regex += NSRegularExpression.escapedPattern(for: component)
                }
            }

            if index < components.count - 1 {
                regex += NSRegularExpression.escapedPattern(for: "/")
            }
        }

        if case .exact = policy {
            regex += "$"
        }

        // swiftlint:disable:next force_try
        return try! NSRegularExpression(pattern: regex, options: [])
    }
}
