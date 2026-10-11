import Foundation

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

    /// Registers a typed handler.
    ///
    /// The conveniences in the protocol extension supply defaults for
    /// `host`, `matching`, and `supportFragmentParams`, and also accept
    /// handlers that receive the parameter dictionary instead of the request.
    ///
    /// - Parameters:
    ///   - host: The URL host the handler accepts, compared case-insensitively,
    ///     or `nil` for a hostless registration.
    ///   - type: The route model whose ``PathwayPatternProvider/pattern`` is
    ///     matched and decoded.
    ///   - matching: The policy used to match the route.
    ///   - supportFragmentParams: Whether to merge query items following a
    ///     fragment route into the request's parameters and query items.
    ///   - handler: The main-actor closure invoked with the decoded route and
    ///     the request.
    /// - Important: A hostless registration can handle URLs whose host equals
    ///   ``baseHost`` or a host declared by another registration.
    mutating func register<T: Pathway>(
        host: String?,
        _ type: T.Type,
        matching: PathwayMatchPolicy,
        supportFragmentParams: Bool,
        handler: @MainActor @Sendable @escaping (T, PathwayRequest) -> Void
    )

    /// Registers a path handler.
    ///
    /// The conveniences in the protocol extension supply defaults for
    /// `host`, `matching`, and `supportFragmentParams`, and also accept
    /// handlers that receive the parameter dictionary instead of the request.
    ///
    /// - Parameters:
    ///   - host: The URL host the handler accepts, compared case-insensitively,
    ///     or `nil` for a hostless registration.
    ///   - path: The path the handler accepts.
    ///   - matching: The policy used to match the path.
    ///   - supportFragmentParams: Whether to merge query items following a
    ///     fragment route into the request's parameters and query items.
    ///   - handler: The main-actor closure invoked with the request.
    /// - Important: A hostless registration can handle URLs whose host equals
    ///   ``baseHost`` or a host declared by another registration.
    mutating func register(
        host: String?,
        path: String,
        matching: PathwayMatchPolicy,
        supportFragmentParams: Bool,
        handler: @MainActor @Sendable @escaping (PathwayRequest) -> Void
    )

    /// Handles a URL with the best matching registered handler.
    ///
    /// - Parameter url: The incoming URL to route.
    /// - Returns: `true` if a handler ran; otherwise, `false` when the URL
    ///   scheme is not allowed, the URL host is not registered, or no handler
    ///   matches. A URL without a host, such as `myapp:///products/42`, is
    ///   considered only by hostless registrations, and only while
    ///   ``baseHost`` is empty.
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

    /// Registers a typed handler for one exact host.
    ///
    /// - Parameters:
    ///   - host: The URL host the handler accepts, compared case-insensitively.
    ///   - type: The route model whose ``PathwayPatternProvider/pattern`` is
    ///     matched and decoded.
    ///   - matching: The policy used to match the route. Defaults to
    ///     ``PathwayMatchPolicy/prefix``.
    ///   - supportFragmentParams: Whether to merge query items following a
    ///     fragment route into the handler's parameter dictionary. Defaults to
    ///     `false`.
    ///   - handler: The main-actor closure invoked with the decoded route and
    ///     URL parameters.
    mutating func register<T: Pathway>(
        host: String,
        _ type: T.Type,
        matching: PathwayMatchPolicy = .prefix,
        supportFragmentParams: Bool = false,
        handler: @MainActor @Sendable @escaping (T, [String: String]) -> Void
    ) {
        register(host: String?.some(host), type, matching: matching, supportFragmentParams: supportFragmentParams, handler: { route, request in handler(route, request.parameters) })
    }

    /// Registers a typed handler without restricting it to a specific host.
    ///
    /// - Parameters:
    ///   - type: The route model whose ``PathwayPatternProvider/pattern`` is
    ///     matched and decoded.
    ///   - matching: The policy used to match the route. Defaults to
    ///     ``PathwayMatchPolicy/prefix``.
    ///   - supportFragmentParams: Whether to merge query items following a
    ///     fragment route into the handler's parameter dictionary. Defaults to
    ///     `false`.
    ///   - handler: The main-actor closure invoked with the decoded route and
    ///     URL parameters.
    /// - Important: A hostless registration can handle URLs whose host equals
    ///   ``baseHost`` or a host declared by another registration.
    mutating func register<T: Pathway>(
        _ type: T.Type,
        matching: PathwayMatchPolicy = .prefix,
        supportFragmentParams: Bool = false,
        handler: @MainActor @Sendable @escaping (T, [String: String]) -> Void
    ) {
        register(host: nil, type, matching: matching, supportFragmentParams: supportFragmentParams, handler: { route, request in handler(route, request.parameters) })
    }

    /// Registers a path handler for one exact host.
    ///
    /// - Parameters:
    ///   - host: The URL host the handler accepts, compared case-insensitively.
    ///   - path: The path the handler accepts.
    ///   - matching: The policy used to match the path. Defaults to
    ///     ``PathwayMatchPolicy/prefix``.
    ///   - supportFragmentParams: Whether to merge query items following a
    ///     fragment route into the handler's parameter dictionary. Defaults to
    ///     `false`.
    ///   - handler: The main-actor closure invoked with URL parameters.
    mutating func register(
        host: String,
        path: String,
        matching: PathwayMatchPolicy = .prefix,
        supportFragmentParams: Bool = false,
        handler: @MainActor @Sendable @escaping ([String: String]) -> Void
    ) {
        register(host: String?.some(host), path: path, matching: matching, supportFragmentParams: supportFragmentParams, handler: { request in handler(request.parameters) })
    }

    /// Registers a path handler without restricting it to a specific host.
    ///
    /// - Parameters:
    ///   - path: The path the handler accepts.
    ///   - matching: The policy used to match the path. Defaults to
    ///     ``PathwayMatchPolicy/prefix``.
    ///   - supportFragmentParams: Whether to merge query items following a
    ///     fragment route into the handler's parameter dictionary. Defaults to
    ///     `false`.
    ///   - handler: The main-actor closure invoked with URL parameters.
    /// - Important: A hostless registration can handle URLs whose host equals
    ///   ``baseHost`` or a host declared by another registration.
    mutating func register(
        path: String,
        matching: PathwayMatchPolicy = .prefix,
        supportFragmentParams: Bool = false,
        handler: @MainActor @Sendable @escaping ([String: String]) -> Void
    ) {
        register(host: nil, path: path, matching: matching, supportFragmentParams: supportFragmentParams, handler: { request in handler(request.parameters) })
    }

    /// Registers a typed handler for one exact host.
    ///
    /// - Parameters:
    ///   - host: The URL host the handler accepts, compared case-insensitively.
    ///   - type: The route model whose ``PathwayPatternProvider/pattern`` is
    ///     matched and decoded.
    ///   - matching: The policy used to match the route. Defaults to
    ///     ``PathwayMatchPolicy/prefix``.
    ///   - supportFragmentParams: Whether to merge query items following a
    ///     fragment route into the request's parameters and query items. Defaults to
    ///     `false`.
    ///   - handler: The main-actor closure invoked with the decoded route and
    ///     the request.
    @_disfavoredOverload
    mutating func register<T: Pathway>(
        host: String,
        _ type: T.Type,
        matching: PathwayMatchPolicy = .prefix,
        supportFragmentParams: Bool = false,
        handler: @MainActor @Sendable @escaping (T, PathwayRequest) -> Void
    ) {
        register(host: String?.some(host), type, matching: matching, supportFragmentParams: supportFragmentParams, handler: handler)
    }

    /// Registers a typed handler without restricting it to a specific host.
    ///
    /// - Parameters:
    ///   - type: The route model whose ``PathwayPatternProvider/pattern`` is
    ///     matched and decoded.
    ///   - matching: The policy used to match the route. Defaults to
    ///     ``PathwayMatchPolicy/prefix``.
    ///   - supportFragmentParams: Whether to merge query items following a
    ///     fragment route into the request's parameters and query items. Defaults to
    ///     `false`.
    ///   - handler: The main-actor closure invoked with the decoded route and
    ///     the request.
    /// - Important: A hostless registration can handle URLs whose host equals
    ///   ``baseHost`` or a host declared by another registration.
    @_disfavoredOverload
    mutating func register<T: Pathway>(
        _ type: T.Type,
        matching: PathwayMatchPolicy = .prefix,
        supportFragmentParams: Bool = false,
        handler: @MainActor @Sendable @escaping (T, PathwayRequest) -> Void
    ) {
        register(host: nil, type, matching: matching, supportFragmentParams: supportFragmentParams, handler: handler)
    }

    /// Registers a path handler for one exact host.
    ///
    /// - Parameters:
    ///   - host: The URL host the handler accepts, compared case-insensitively.
    ///   - path: The path the handler accepts.
    ///   - matching: The policy used to match the path. Defaults to
    ///     ``PathwayMatchPolicy/prefix``.
    ///   - supportFragmentParams: Whether to merge query items following a
    ///     fragment route into the request's parameters and query items. Defaults to
    ///     `false`.
    ///   - handler: The main-actor closure invoked with the request.
    @_disfavoredOverload
    mutating func register(
        host: String,
        path: String,
        matching: PathwayMatchPolicy = .prefix,
        supportFragmentParams: Bool = false,
        handler: @MainActor @Sendable @escaping (PathwayRequest) -> Void
    ) {
        register(host: String?.some(host), path: path, matching: matching, supportFragmentParams: supportFragmentParams, handler: handler)
    }

    /// Registers a path handler without restricting it to a specific host.
    ///
    /// - Parameters:
    ///   - path: The path the handler accepts.
    ///   - matching: The policy used to match the path. Defaults to
    ///     ``PathwayMatchPolicy/prefix``.
    ///   - supportFragmentParams: Whether to merge query items following a
    ///     fragment route into the request's parameters and query items. Defaults to
    ///     `false`.
    ///   - handler: The main-actor closure invoked with the request.
    /// - Important: A hostless registration can handle URLs whose host equals
    ///   ``baseHost`` or a host declared by another registration.
    @_disfavoredOverload
    mutating func register(
        path: String,
        matching: PathwayMatchPolicy = .prefix,
        supportFragmentParams: Bool = false,
        handler: @MainActor @Sendable @escaping (PathwayRequest) -> Void
    ) {
        register(host: nil, path: path, matching: matching, supportFragmentParams: supportFragmentParams, handler: handler)
    }
}
