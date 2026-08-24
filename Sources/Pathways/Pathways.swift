import Foundation

/// A value-based router that dispatches URLs to registered handlers.
///
/// Register typed ``Pathway`` route models or path handlers, then
/// call ``handle(_:)`` for each incoming URL.
public struct Pathways: PathwaysProviding {

    /// The host accepted by registrations that do not specify their own host.
    ///
    /// Set this before handling URLs with hostless registrations.
    public var baseHost: String = ""

    /// The list of hadnlers
    private var handlers: [any PathwayHandling] = []

    /// Creates a routing center with no registered handlers and an empty base host.
    public init() {}

    /// Registers a typed handler for one exact host.
    ///
    /// - Parameters:
    ///   - host: The exact URL host the handler accepts.
    ///   - type: The route model whose ``PathwayPatternProvider/pattern`` is
    ///     matched and decoded.
    ///   - supportFragmentParams: Whether to merge query items following a
    ///     fragment route into the handler's parameter dictionary.
    ///   - handler: The main-actor closure invoked with the decoded route and
    ///     URL parameters.
    /// - Important: This overload uses ``PathwayMatchPolicy/prefix``.
    public mutating func register<T: Pathway>(
        host: String,
        _: T.Type,
        supportFragmentParams: Bool = false,
        handler: @escaping @MainActor @Sendable (T, [String: String]) -> Void
    ) {
        register(
            host: host,
            T.self,
            matching: .prefix,
            supportFragmentParams: supportFragmentParams,
            handler: handler
        )
    }

    /// Registers a typed handler for one exact host.
    ///
    /// - Parameters:
    ///   - host: The exact URL host the handler accepts.
    ///   - type: The route model whose ``PathwayPatternProvider/pattern`` is
    ///     matched and decoded.
    ///   - matching: The policy used to match the route.
    ///   - supportFragmentParams: Whether to merge query items following a
    ///     fragment route into the handler's parameter dictionary.
    ///   - handler: The main-actor closure invoked with the decoded route and
    ///     URL parameters.
    public mutating func register<T: Pathway>(
        host: String,
        _: T.Type,
        matching: PathwayMatchPolicy,
        supportFragmentParams: Bool = false,
        handler: @escaping @MainActor @Sendable (T, [String: String]) -> Void
    ) {
        handlers.append(PathwayPatternHandler(
            host: host,
            matching: matching,
            supportFragmentParams: supportFragmentParams,
            handler
        ))
    }

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
    ///   This overload uses ``PathwayMatchPolicy/prefix``.
    public mutating func register<T: Pathway>(
        _: T.Type,
        supportFragmentParams: Bool = false,
        handler: @escaping @MainActor @Sendable (T, [String: String]) -> Void
    ) {
        register(
            T.self,
            matching: .prefix,
            supportFragmentParams: supportFragmentParams,
            handler: handler
        )
    }

    /// Registers a typed handler without restricting it to a specific host.
    ///
    /// - Parameters:
    ///   - type: The route model whose ``PathwayPatternProvider/pattern`` is
    ///     matched and decoded.
    ///   - matching: The policy used to match the route.
    ///   - supportFragmentParams: Whether to merge query items following a
    ///     fragment route into the handler's parameter dictionary.
    ///   - handler: The main-actor closure invoked with the decoded route and
    ///     URL parameters.
    /// - Important: A hostless registration can handle URLs whose host equals
    ///   ``baseHost`` or a host declared by another registration.
    public mutating func register<T: Pathway>(
        _: T.Type,
        matching: PathwayMatchPolicy,
        supportFragmentParams: Bool = false,
        handler: @escaping @MainActor @Sendable (T, [String: String]) -> Void
    ) {
        handlers.append(PathwayPatternHandler(matching: matching, supportFragmentParams: supportFragmentParams, handler))
    }

    /// Registers a path handler for one exact host.
    ///
    /// - Parameters:
    ///   - host: The exact URL host the handler accepts.
    ///   - path: The path prefix the handler accepts.
    ///   - supportFragmentParams: Whether to merge query items following a
    ///     fragment route into the handler's parameter dictionary.
    ///   - handler: The main-actor closure invoked with URL parameters.
    /// - Important: This overload uses ``PathwayMatchPolicy/prefix``.
    public mutating func register(
        host: String,
        path: String,
        supportFragmentParams: Bool = false,
        handler: @escaping @MainActor @Sendable ([String: String]) -> Void
    ) {
        register(
            host: host,
            path: path,
            matching: .prefix,
            supportFragmentParams: supportFragmentParams,
            handler: handler
        )
    }

    /// Registers a path handler for one exact host.
    ///
    /// - Parameters:
    ///   - host: The exact URL host the handler accepts.
    ///   - path: The path the handler accepts.
    ///   - matching: The policy used to match the path.
    ///   - supportFragmentParams: Whether to merge query items following a
    ///     fragment route into the handler's parameter dictionary.
    ///   - handler: The main-actor closure invoked with URL parameters.
    public mutating func register(
        host: String,
        path: String,
        matching: PathwayMatchPolicy,
        supportFragmentParams: Bool = false,
        handler: @escaping @MainActor @Sendable ([String: String]) -> Void
    ) {
        handlers.append(PathwayPathHandler(
            host: host,
            path: path,
            matching: matching,
            supportFragmentParams: supportFragmentParams,
            handler: handler
        ))
    }

    /// Registers a path handler without restricting it to a specific host.
    ///
    /// - Parameters:
    ///   - path: The path prefix the handler accepts.
    ///   - supportFragmentParams: Whether to merge query items following a
    ///     fragment route into the handler's parameter dictionary.
    ///   - handler: The main-actor closure invoked with URL parameters.
    /// - Important: A hostless registration can handle URLs whose host equals
    ///   ``baseHost`` or a host declared by another registration.
    ///   This overload uses ``PathwayMatchPolicy/prefix``.
    public mutating func register(
        path: String,
        supportFragmentParams: Bool = false,
        handler: @MainActor @Sendable @escaping ([String: String]) -> Void
    ) {
        register(
            path: path,
            matching: .prefix,
            supportFragmentParams: supportFragmentParams,
            handler: handler
        )
    }

    /// Registers a path handler without restricting it to a specific host.
    ///
    /// - Parameters:
    ///   - path: The path the handler accepts.
    ///   - matching: The policy used to match the path.
    ///   - supportFragmentParams: Whether to merge query items following a
    ///     fragment route into the handler's parameter dictionary.
    ///   - handler: The main-actor closure invoked with URL parameters.
    /// - Important: A hostless registration can handle URLs whose host equals
    ///   ``baseHost`` or a host declared by another registration.
    public mutating func register(
        path: String,
        matching: PathwayMatchPolicy,
        supportFragmentParams: Bool = false,
        handler: @MainActor @Sendable @escaping ([String: String]) -> Void
    ) {
        handlers.append(PathwayPathHandler(
            path: path,
            matching: matching,
            supportFragmentParams: supportFragmentParams,
            handler: handler
        ))
    }

    /// Handles a URL with the best matching registered handler.
    ///
    /// - Parameter url: The incoming URL to route.
    /// - Returns: `true` if a handler ran; otherwise, `false` when the URL host
    ///   is not registered or no handler matches.
    /// - Throws: Any error thrown while decoding a matching typed route.
    /// - Important: When several handlers match, Pathways selects the handler
    ///   with the lexicographically greatest pattern. Do not rely on registration
    ///   order as a precedence mechanism.
    @MainActor public func handle(_ url: URL) throws -> Bool {

        var registeredHosts = Set(registeredHosts())
        registeredHosts.insert(baseHost)

        guard let host = url.host, registeredHosts.contains(host) else {
            return false
        }

        if let handler = handlers
            .filter({ $0.canHandle(url) })
            .sorted(by: { lhs, rhs in
                lhs.pattern > rhs.pattern
            })
            .first {
            try handler.handle(url: url)
            return true
        }
        return false
    }

    /// Removes every registered handler.
    ///
    /// This does not change ``baseHost``.
    public mutating func reset() {
        handlers.removeAll()
    }

    /// Returns the patterns declared by registered handlers.
    ///
    /// - Returns: Registered patterns in ascending lexical order.
    public func registeredPatterns() -> [String] {
        handlers.map(\.pattern).sorted()
    }

    /// Returns the exact hosts declared by host-specific registrations.
    ///
    /// - Returns: Registered hosts in ascending lexical order. This does not
    ///   include ``baseHost``.
    public func registeredHosts() -> [String] {
        handlers.compactMap(\.host).sorted()
    }
}
