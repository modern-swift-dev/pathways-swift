import Foundation

// sourcery: AutoMockable
/// Describes a router that dispatches incoming URLs to registered handlers.
///
/// Implement this protocol to provide a custom routing center compatible with
/// Pathways route registrations.
public protocol PathwaysProviding: Sendable {

    /// The host accepted by registrations that do not specify their own host.
    ///
    /// Set this to the host of URLs your application accepts before calling
    /// ``handle(_:)`` for hostless registrations.
    var baseHost: String { get set }

    /// The URL schemes accepted by every registration, compared case-insensitively.
    ///
    /// `nil` accepts any scheme.
    var allowedSchemes: Set<String>? { get set }

    /// Registers a typed handler without restricting it to a specific host.
    ///
    /// - Parameters:
    ///   - type: The route model whose ``PathwayPatternProvider/pattern`` is
    ///     matched and decoded.
    ///   - supportFragmentParams: Whether to merge query items following a
    ///     fragment route into the handler's parameter dictionary.
    ///   - handler: The main-actor closure invoked with the decoded route and
    ///     URL parameters.
    /// - Important: A hostless registration can handle URLs whose host equals
    ///   ``baseHost`` or a host declared by another registration.
    mutating func register<T: Pathway>(
        _ type: T.Type,
        supportFragmentParams: Bool,
        handler: @MainActor @Sendable @escaping (T, [String: String]) -> Void
    )

    /// Registers a typed handler for one exact host.
    ///
    /// - Parameters:
    ///   - host: The URL host the handler accepts, compared case-insensitively.
    ///   - type: The route model whose ``PathwayPatternProvider/pattern`` is
    ///     matched and decoded.
    ///   - supportFragmentParams: Whether to merge query items following a
    ///     fragment route into the handler's parameter dictionary.
    ///   - handler: The main-actor closure invoked with the decoded route and
    ///     URL parameters.
    mutating func register<T: Pathway>(
        host: String,
        _ type: T.Type,
        supportFragmentParams: Bool,
        handler: @MainActor @Sendable @escaping (T, [String: String]) -> Void
    )

    /// Registers a path-prefix handler without restricting it to a specific host.
    ///
    /// - Parameters:
    ///   - path: The path prefix the handler accepts.
    ///   - supportFragmentParams: Whether to merge query items following a
    ///     fragment route into the handler's parameter dictionary.
    ///   - handler: The main-actor closure invoked with URL parameters.
    /// - Important: A hostless registration can handle URLs whose host equals
    ///   ``baseHost`` or a host declared by another registration. Path matching
    ///   is prefix-based.
    mutating func register(
        path: String,
        supportFragmentParams: Bool,
        handler: @MainActor @Sendable @escaping ([String: String]) -> Void
    )

    /// Registers a path-prefix handler for one exact host.
    ///
    /// - Parameters:
    ///   - host: The URL host the handler accepts, compared case-insensitively.
    ///   - path: The path prefix the handler accepts.
    ///   - supportFragmentParams: Whether to merge query items following a
    ///     fragment route into the handler's parameter dictionary.
    ///   - handler: The main-actor closure invoked with URL parameters.
    /// - Important: Path matching is prefix-based.
    mutating func register(
        host: String,
        path: String,
        supportFragmentParams: Bool,
        handler: @MainActor @Sendable @escaping ([String: String]) -> Void
    )

    /// Registers a typed handler with an explicit matching policy.
    mutating func register<T: Pathway>(
        _ type: T.Type,
        matching: PathwayMatchPolicy,
        supportFragmentParams: Bool,
        handler: @MainActor @Sendable @escaping (T, [String: String]) -> Void
    )

    /// Registers a typed handler for one exact host with an explicit matching policy.
    mutating func register<T: Pathway>(
        host: String,
        _ type: T.Type,
        matching: PathwayMatchPolicy,
        supportFragmentParams: Bool,
        handler: @MainActor @Sendable @escaping (T, [String: String]) -> Void
    )

    /// Registers a path handler with an explicit matching policy.
    mutating func register(
        path: String,
        matching: PathwayMatchPolicy,
        supportFragmentParams: Bool,
        handler: @MainActor @Sendable @escaping ([String: String]) -> Void
    )

    /// Registers a path handler for one exact host with an explicit matching policy.
    mutating func register(
        host: String,
        path: String,
        matching: PathwayMatchPolicy,
        supportFragmentParams: Bool,
        handler: @MainActor @Sendable @escaping ([String: String]) -> Void
    )

    /// Handles a URL with the best matching registered handler.
    ///
    /// - Parameter url: The incoming URL to route.
    /// - Returns: `true` if a handler ran; otherwise, `false` when the URL
    ///   scheme is not allowed, the URL host is not registered, or no handler
    ///   matches.
    /// - Throws: Any error thrown while decoding a matching typed route.
    /// - Important: When several handlers match, Pathways selects the most
    ///   specific one. At the first path component where two patterns differ,
    ///   a literal beats a `:` placeholder; otherwise the longer pattern wins,
    ///   then exact matching beats prefix matching, then a host-specific
    ///   registration beats a hostless one. Equally specific registrations
    ///   keep the first one registered.
    @MainActor func handle(_ url: URL) throws -> Bool

    /// Removes every registered handler.
    ///
    /// This does not change ``baseHost``.
    mutating func reset()

    /// Returns the exact hosts declared by host-specific registrations.
    ///
    /// - Returns: Registered hosts, lowercased, in ascending lexical order. This does not
    ///   include ``baseHost``.
    func registeredHosts() -> [String]

    /// Returns the patterns declared by registered handlers.
    ///
    /// - Returns: Registered patterns in ascending lexical order.
    func registeredPatterns() -> [String]
}

public extension PathwaysProviding {

    /// Registers a typed handler without restricting it to a specific host.
    ///
    /// Fragment parameters are not delivered to the handler.
    mutating func register<T: Pathway>(
        _ type: T.Type,
        matching: PathwayMatchPolicy = .prefix,
        handler: @MainActor @Sendable @escaping (T, [String: String]) -> Void
    ) {
        register(type, matching: matching, supportFragmentParams: false, handler: handler)
    }

    /// Registers a typed handler for one host.
    ///
    /// Fragment parameters are not delivered to the handler.
    mutating func register<T: Pathway>(
        host: String,
        _ type: T.Type,
        matching: PathwayMatchPolicy = .prefix,
        handler: @MainActor @Sendable @escaping (T, [String: String]) -> Void
    ) {
        register(host: host, type, matching: matching, supportFragmentParams: false, handler: handler)
    }

    /// Registers a path handler without restricting it to a specific host.
    ///
    /// Fragment parameters are not delivered to the handler.
    mutating func register(
        path: String,
        matching: PathwayMatchPolicy = .prefix,
        handler: @MainActor @Sendable @escaping ([String: String]) -> Void
    ) {
        register(path: path, matching: matching, supportFragmentParams: false, handler: handler)
    }

    /// Registers a path handler for one host.
    ///
    /// Fragment parameters are not delivered to the handler.
    mutating func register(
        host: String,
        path: String,
        matching: PathwayMatchPolicy = .prefix,
        handler: @MainActor @Sendable @escaping ([String: String]) -> Void
    ) {
        register(host: host, path: path, matching: matching, supportFragmentParams: false, handler: handler)
    }
}
