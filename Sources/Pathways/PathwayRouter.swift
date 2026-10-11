import Foundation

/// A value-based router that dispatches URLs to registered handlers.
///
/// Register typed ``Pathway`` route models or path handlers, then
/// call ``handle(_:)`` for each incoming URL.
public struct PathwayRouter: PathwaysProviding {

    /// The host accepted by registrations that do not specify their own host.
    ///
    /// Set this before handling URLs with hostless registrations.
    public var baseHost: String = ""

    /// The URL schemes accepted by every registration, compared case-insensitively.
    ///
    /// The default, `nil`, accepts any scheme. Set this to `["https"]` to
    /// ignore the same paths delivered through other schemes.
    public var allowedSchemes: Set<String>?

    /// The registered handlers
    private var handlers: [any PathwayHandling] = []

    /// Creates a routing center with no registered handlers and an empty base host.
    public init() {}

    /// Registers a typed handler.
    ///
    /// Prefer the ``PathwaysProviding`` conveniences, which supply defaults
    /// for `host`, `matching`, and `supportFragmentParams`.
    ///
    /// - Parameters:
    ///   - host: The URL host the handler accepts, compared case-insensitively,
    ///     or `nil` for a hostless registration.
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
        host: String?,
        _: T.Type,
        matching: PathwayMatchPolicy,
        supportFragmentParams: Bool,
        handler: @escaping @MainActor @Sendable (T, [String: String]) -> Void
    ) {
        handlers.append(PathwayPatternHandler(
            host: host,
            matching: matching,
            supportFragmentParams: supportFragmentParams,
            handler
        ))
    }

    /// Registers a path handler.
    ///
    /// Prefer the ``PathwaysProviding`` conveniences, which supply defaults
    /// for `host`, `matching`, and `supportFragmentParams`.
    ///
    /// - Parameters:
    ///   - host: The URL host the handler accepts, compared case-insensitively,
    ///     or `nil` for a hostless registration.
    ///   - path: The path the handler accepts.
    ///   - matching: The policy used to match the path.
    ///   - supportFragmentParams: Whether to merge query items following a
    ///     fragment route into the handler's parameter dictionary.
    ///   - handler: The main-actor closure invoked with URL parameters.
    /// - Important: A hostless registration can handle URLs whose host equals
    ///   ``baseHost`` or a host declared by another registration.
    public mutating func register(
        host: String?,
        path: String,
        matching: PathwayMatchPolicy,
        supportFragmentParams: Bool,
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
    @MainActor public func handle(_ url: URL) throws -> Bool {

        if let allowedSchemes {
            guard let scheme = url.scheme?.lowercased(),
                  allowedSchemes.contains(where: { $0.lowercased() == scheme }) else {
                return false
            }
        }

        guard let host = url.host?.lowercased(),
              host == baseHost.lowercased() || handlers.contains(where: { $0.host == host }) else {
            return false
        }

        let components = url.pathwayPathComponents
        var bestHandler: (any PathwayHandling)?
        for handler in handlers where handler.canHandle(host: host, components: components) {
            if let current = bestHandler, !handler.isMoreSpecific(than: current) {
                continue
            }
            bestHandler = handler
        }

        if let handler = bestHandler {
            try handler.handle(url: url, components: components)
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
    /// - Returns: Registered hosts, lowercased, in ascending lexical order. This does not
    ///   include ``baseHost``.
    public func registeredHosts() -> [String] {
        handlers.compactMap(\.host).sorted()
    }
}
