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

    /// The handler for admitted URLs that no registration handles.
    ///
    /// The fallback receives the request when no registration matches the
    /// URL or every matching handler declines, so ``handle(_:)`` returns
    /// `true`. It does not run for URLs rejected by ``allowedSchemes`` or
    /// whose host is not admitted, nor after a decode error. Its request does
    /// not include fragment parameters. `nil`, the default, disables it.
    var fallback: (@MainActor @Sendable (PathwayRequest) -> Void)? { get set }

    /// Registers a typed handler.
    ///
    /// The conveniences in the protocol extension supply defaults for
    /// `host`, `matching`, and `supportFragmentParams`, and also accept
    /// handlers that receive the parameter dictionary instead of the request,
    /// which always handle the URL.
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
    ///     the request. Return ``PathwayHandlerResult/declined`` to let the
    ///     next most specific matching registration handle the URL.
    /// - Returns: An identifier that ``unregister(_:)`` accepts to remove
    ///   this registration.
    /// - Important: A hostless registration can handle URLs whose host equals
    ///   ``baseHost`` or a host declared by another registration.
    @discardableResult
    mutating func register<T: Pathway>(
        host: String?,
        _ type: T.Type,
        matching: PathwayMatchPolicy,
        supportFragmentParams: Bool,
        handler: @MainActor @Sendable @escaping (T, PathwayRequest) -> PathwayHandlerResult
    ) -> PathwayRegistrationID

    /// Registers a path handler.
    ///
    /// The conveniences in the protocol extension supply defaults for
    /// `host`, `matching`, and `supportFragmentParams`, and also accept
    /// handlers that receive the parameter dictionary instead of the request,
    /// which always handle the URL.
    ///
    /// - Parameters:
    ///   - host: The URL host the handler accepts, compared case-insensitively,
    ///     or `nil` for a hostless registration.
    ///   - path: The path the handler accepts.
    ///   - matching: The policy used to match the path.
    ///   - supportFragmentParams: Whether to merge query items following a
    ///     fragment route into the request's parameters and query items.
    ///   - handler: The main-actor closure invoked with the request. Return
    ///     ``PathwayHandlerResult/declined`` to let the next most specific
    ///     matching registration handle the URL.
    /// - Returns: An identifier that ``unregister(_:)`` accepts to remove
    ///   this registration.
    /// - Important: A hostless registration can handle URLs whose host equals
    ///   ``baseHost`` or a host declared by another registration.
    @discardableResult
    mutating func register(
        host: String?,
        path: String,
        matching: PathwayMatchPolicy,
        supportFragmentParams: Bool,
        handler: @MainActor @Sendable @escaping (PathwayRequest) -> PathwayHandlerResult
    ) -> PathwayRegistrationID

    /// Handles a URL with the best matching registered handler.
    ///
    /// - Parameter url: The incoming URL to route.
    /// - Returns: `true` if a handler or the ``fallback`` handled the URL;
    ///   otherwise, `false` when the URL scheme is not allowed, the URL host
    ///   is not registered, or no handler matches or every matching handler
    ///   declines and there is no fallback. A URL without a host, such as `myapp:///products/42`, is
    ///   considered only by hostless registrations, and only while
    ///   ``baseHost`` is empty.
    /// - Throws: Any error thrown while decoding a matching typed route. A
    ///   decode error stops routing rather than falling through.
    /// - Important: When several handlers match, Pathways selects the most
    ///   specific one. At the first path component where two patterns differ,
    ///   a literal beats a `:` placeholder; otherwise the longer pattern wins,
    ///   then exact matching beats prefix matching, then a host-specific
    ///   registration beats a hostless one. Equally specific registrations
    ///   keep the first one registered. When the selected handler returns
    ///   ``PathwayHandlerResult/declined``, routing falls through to the next
    ///   handler in that order.
    @MainActor func handle(_ url: URL) throws -> Bool

    /// Removes one registration.
    ///
    /// Other registrations, including those for the same pattern, keep
    /// working. Unregistering an unknown or already-removed identifier does
    /// nothing.
    ///
    /// - Parameter registration: The identifier returned when registering.
    mutating func unregister(_ registration: PathwayRegistrationID)

    /// Removes every registered handler.
    ///
    /// This does not change ``baseHost``, ``allowedSchemes``, or ``fallback``.
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
    ///     fragment route into the request's parameters and query items. Defaults to
    ///     `false`.
    ///   - handler: The main-actor closure invoked with the decoded route and
    ///     the request. Return ``PathwayHandlerResult/declined`` to let the
    ///     next most specific matching registration handle the URL.
    /// - Returns: An identifier that ``unregister(_:)`` accepts to remove
    ///   this registration.
    @_disfavoredOverload
    @discardableResult
    mutating func register<T: Pathway>(
        host: String,
        _ type: T.Type,
        matching: PathwayMatchPolicy = .prefix,
        supportFragmentParams: Bool = false,
        handler: @MainActor @Sendable @escaping (T, PathwayRequest) -> PathwayHandlerResult
    ) -> PathwayRegistrationID {
        register(
            host: String?.some(host),
            type,
            matching: matching,
            supportFragmentParams: supportFragmentParams,
            handler: handler
        )
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
    ///     the request. Return ``PathwayHandlerResult/declined`` to let the
    ///     next most specific matching registration handle the URL.
    /// - Returns: An identifier that ``unregister(_:)`` accepts to remove
    ///   this registration.
    /// - Important: A hostless registration can handle URLs whose host equals
    ///   ``baseHost`` or a host declared by another registration.
    @_disfavoredOverload
    @discardableResult
    mutating func register<T: Pathway>(
        _ type: T.Type,
        matching: PathwayMatchPolicy = .prefix,
        supportFragmentParams: Bool = false,
        handler: @MainActor @Sendable @escaping (T, PathwayRequest) -> PathwayHandlerResult
    ) -> PathwayRegistrationID {
        register(
            host: nil,
            type,
            matching: matching,
            supportFragmentParams: supportFragmentParams,
            handler: handler
        )
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
    ///   - handler: The main-actor closure invoked with the request. Return
    ///     ``PathwayHandlerResult/declined`` to let the next most specific
    ///     matching registration handle the URL.
    /// - Returns: An identifier that ``unregister(_:)`` accepts to remove
    ///   this registration.
    @_disfavoredOverload
    @discardableResult
    mutating func register(
        host: String,
        path: String,
        matching: PathwayMatchPolicy = .prefix,
        supportFragmentParams: Bool = false,
        handler: @MainActor @Sendable @escaping (PathwayRequest) -> PathwayHandlerResult
    ) -> PathwayRegistrationID {
        register(
            host: String?.some(host),
            path: path,
            matching: matching,
            supportFragmentParams: supportFragmentParams,
            handler: handler
        )
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
    ///   - handler: The main-actor closure invoked with the request. Return
    ///     ``PathwayHandlerResult/declined`` to let the next most specific
    ///     matching registration handle the URL.
    /// - Returns: An identifier that ``unregister(_:)`` accepts to remove
    ///   this registration.
    /// - Important: A hostless registration can handle URLs whose host equals
    ///   ``baseHost`` or a host declared by another registration.
    @_disfavoredOverload
    @discardableResult
    mutating func register(
        path: String,
        matching: PathwayMatchPolicy = .prefix,
        supportFragmentParams: Bool = false,
        handler: @MainActor @Sendable @escaping (PathwayRequest) -> PathwayHandlerResult
    ) -> PathwayRegistrationID {
        register(
            host: nil,
            path: path,
            matching: matching,
            supportFragmentParams: supportFragmentParams,
            handler: handler
        )
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
    ///     fragment route into the handler's parameter dictionary. Defaults to
    ///     `false`.
    ///   - handler: The main-actor closure invoked with the decoded route and
    ///     URL parameters. The handler always handles the URL.
    /// - Returns: An identifier that ``unregister(_:)`` accepts to remove
    ///   this registration.
    @discardableResult
    mutating func register<T: Pathway>(
        host: String,
        _ type: T.Type,
        matching: PathwayMatchPolicy = .prefix,
        supportFragmentParams: Bool = false,
        handler: @MainActor @Sendable @escaping (T, [String: String]) -> Void
    ) -> PathwayRegistrationID {
        register(
            host: String?.some(host),
            type,
            matching: matching,
            supportFragmentParams: supportFragmentParams,
            handler: { route, request in
                handler(route, request.parameters)
                return .handled
            }
        )
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
    ///     URL parameters. The handler always handles the URL.
    /// - Returns: An identifier that ``unregister(_:)`` accepts to remove
    ///   this registration.
    /// - Important: A hostless registration can handle URLs whose host equals
    ///   ``baseHost`` or a host declared by another registration.
    @discardableResult
    mutating func register<T: Pathway>(
        _ type: T.Type,
        matching: PathwayMatchPolicy = .prefix,
        supportFragmentParams: Bool = false,
        handler: @MainActor @Sendable @escaping (T, [String: String]) -> Void
    ) -> PathwayRegistrationID {
        register(
            host: nil,
            type,
            matching: matching,
            supportFragmentParams: supportFragmentParams,
            handler: { route, request in
                handler(route, request.parameters)
                return .handled
            }
        )
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
    ///   - handler: The main-actor closure invoked with URL parameters. The
    ///     handler always handles the URL.
    /// - Returns: An identifier that ``unregister(_:)`` accepts to remove
    ///   this registration.
    @discardableResult
    mutating func register(
        host: String,
        path: String,
        matching: PathwayMatchPolicy = .prefix,
        supportFragmentParams: Bool = false,
        handler: @MainActor @Sendable @escaping ([String: String]) -> Void
    ) -> PathwayRegistrationID {
        register(
            host: String?.some(host),
            path: path,
            matching: matching,
            supportFragmentParams: supportFragmentParams,
            handler: { request in
                handler(request.parameters)
                return .handled
            }
        )
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
    ///   - handler: The main-actor closure invoked with URL parameters. The
    ///     handler always handles the URL.
    /// - Returns: An identifier that ``unregister(_:)`` accepts to remove
    ///   this registration.
    /// - Important: A hostless registration can handle URLs whose host equals
    ///   ``baseHost`` or a host declared by another registration.
    @discardableResult
    mutating func register(
        path: String,
        matching: PathwayMatchPolicy = .prefix,
        supportFragmentParams: Bool = false,
        handler: @MainActor @Sendable @escaping ([String: String]) -> Void
    ) -> PathwayRegistrationID {
        register(
            host: nil,
            path: path,
            matching: matching,
            supportFragmentParams: supportFragmentParams,
            handler: { request in
                handler(request.parameters)
                return .handled
            }
        )
    }
}
