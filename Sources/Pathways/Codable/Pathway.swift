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

/// Matches a canonically percent-encoded path without compiling a regular expression.
struct PathwayMatcher: Sendable {
    private enum Component: Sendable {
        case literal(String)
        case placeholder
    }

    private enum Strategy: Sendable {
        case prefix([String])
        case exact([Component])
        case invalid
    }

    private let strategy: Strategy

    init(pattern: String, matching policy: PathwayMatchPolicy) {
        var components: [Component] = []
        for component in pattern.split(separator: "/") {
            if component.hasPrefix(":") {
                components.append(.placeholder)
            } else if let literal = component.addingPercentEncoding(withAllowedCharacters: .pathwayComponentAllowed) {
                components.append(.literal(literal))
            } else {
                strategy = .invalid
                return
            }
        }

        switch policy {
            case .prefix:
                var literals: [String] = []
                var literal = "/"
                for (index, component) in components.enumerated() {
                    if index > 0 {
                        literal += "/"
                    }
                    switch component {
                        case let .literal(value):
                            literal += value
                        case .placeholder:
                            literals.append(literal)
                            literal = ""
                    }
                }
                literals.append(literal)
                strategy = .prefix(literals)
            case .exact:
                strategy = .exact(components)
        }
    }

    func matches(_ normalizedPath: String) -> Bool {
        switch strategy {
            case let .prefix(literals):
                guard let first = literals.first, normalizedPath.hasPrefix(first) else {
                    return false
                }
                var position = normalizedPath.index(normalizedPath.startIndex, offsetBy: first.count)
                // A wildcard may consume any number of components. Choosing the
                // earliest next literal leaves the most input for later literals.
                for literal in literals.dropFirst() where !literal.isEmpty {
                    guard let range = normalizedPath.range(of: literal, options: .literal, range: position ..< normalizedPath.endIndex) else {
                        return false
                    }
                    position = range.upperBound
                }
                return true
            case let .exact(components):
                guard normalizedPath.hasPrefix("/") else {
                    return false
                }
                if components.isEmpty {
                    return normalizedPath == "/"
                }
                let values = normalizedPath.dropFirst().split(separator: "/", maxSplits: components.count, omittingEmptySubsequences: false)
                guard values.count == components.count else {
                    return false
                }
                for (component, value) in zip(components, values) {
                    switch component {
                        case let .literal(literal):
                            guard value == literal else {
                                return false
                            }
                        case .placeholder:
                            guard !value.isEmpty else {
                                return false
                            }
                    }
                }
                return true
            case .invalid:
                return false
        }
    }
}
