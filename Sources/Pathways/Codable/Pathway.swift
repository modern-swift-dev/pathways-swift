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

/// Matches decoded URL path components against a route pattern.
///
/// Each placeholder matches exactly one non-empty path component.
struct PathwayMatcher: Sendable {
    private enum Component: Sendable {
        case literal(String)
        case placeholder
    }

    private let components: [Component]
    private let matching: PathwayMatchPolicy

    /// Creates a matcher whose `:` components are placeholders.
    init(pattern: String, matching: PathwayMatchPolicy) {
        components = pattern.split(separator: "/").map { $0.hasPrefix(":") ? .placeholder : .literal(String($0)) }
        self.matching = matching
    }

    /// Creates a matcher whose components are all literals.
    init(path: String, matching: PathwayMatchPolicy) {
        components = path.split(separator: "/").map { .literal(String($0)) }
        self.matching = matching
    }

    func matches(_ pathComponents: [String]) -> Bool {
        switch matching {
            case .prefix:
                guard pathComponents.count >= components.count else {
                    return false
                }
            case .exact:
                guard pathComponents.count == components.count else {
                    return false
                }
        }
        return zip(components, pathComponents).allSatisfy { component, value in
            switch component {
                case let .literal(literal):
                    value == literal
                case .placeholder:
                    !value.isEmpty
            }
        }
    }
}
