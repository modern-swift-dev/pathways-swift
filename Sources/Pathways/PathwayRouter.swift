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

    /// The handler for admitted URLs that no registration handles.
    ///
    /// The fallback receives the request when no registration matches the
    /// URL or every matching handler declines, so ``handle(_:)`` returns
    /// `true`. It does not run for URLs rejected by ``allowedSchemes`` or
    /// whose host is not admitted, nor after a decode error. Its request does
    /// not include fragment parameters. `nil`, the default, disables it.
    public var fallback: (@MainActor @Sendable (PathwayRequest) -> Void)?

    /// The registered handlers, in registration order
    private var handlers: [(id: PathwayRegistrationID, handler: any PathwayHandling)] = []

    /// Creates a routing center with no registered handlers and an empty base host.
    public init() {}

    /// Registers a typed handler.
    ///
    /// Prefer the ``PathwaysProviding`` conveniences, which supply defaults
    /// for `host`, `matching`, and `supportFragmentParams`, and also accept
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
    public mutating func register<T: Pathway>(
        host: String?,
        _: T.Type,
        matching: PathwayMatchPolicy,
        supportFragmentParams: Bool,
        handler: @escaping @MainActor @Sendable (T, PathwayRequest) -> PathwayHandlerResult
    ) -> PathwayRegistrationID {
        append(PathwayPatternHandler(
            host: host,
            matching: matching,
            supportFragmentParams: supportFragmentParams,
            handler
        ))
    }

    /// Registers a path handler.
    ///
    /// Prefer the ``PathwaysProviding`` conveniences, which supply defaults
    /// for `host`, `matching`, and `supportFragmentParams`, and also accept
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
    public mutating func register(
        host: String?,
        path: String,
        matching: PathwayMatchPolicy,
        supportFragmentParams: Bool,
        handler: @escaping @MainActor @Sendable (PathwayRequest) -> PathwayHandlerResult
    ) -> PathwayRegistrationID {
        append(PathwayPathHandler(
            host: host,
            path: path,
            matching: matching,
            supportFragmentParams: supportFragmentParams,
            handler: handler
        ))
    }

    private mutating func append(_ handler: any PathwayHandling) -> PathwayRegistrationID {
        let id = PathwayRegistrationID()
        handlers.append((id, handler))
        return id
    }

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
    @MainActor public func handle(_ url: URL) throws -> Bool {

        if let allowedSchemes {
            guard let scheme = url.scheme?.lowercased(),
                  allowedSchemes.contains(where: { $0.lowercased() == scheme }) else {
                return false
            }
        }

        let host: String?
        if let urlHost = url.host?.lowercased(), !urlHost.isEmpty {
            guard urlHost == baseHost.lowercased() || handlers.contains(where: { $0.handler.host == urlHost }) else {
                return false
            }
            host = urlHost
        } else {
            // A custom-scheme URL such as myapp:///products/42 has no host.
            guard url.scheme != nil, baseHost.isEmpty else {
                return false
            }
            host = nil
        }

        let components = url.pathwayPathComponents
        var candidates = handlers.map(\.handler).filter { $0.canHandle(host: host, components: components) }
        while let index = Self.mostSpecificIndex(in: candidates) {
            let handler = candidates.remove(at: index)
            if try handler.handle(url: url, components: components) == .handled {
                return true
            }
        }
        if let fallback {
            fallback(PathwayRequest(url: url, supportFragmentParams: false))
            return true
        }
        return false
    }

    /// Equally specific handlers keep the first one registered.
    private static func mostSpecificIndex(in candidates: [any PathwayHandling]) -> Int? {
        var best: Int?
        for index in candidates.indices {
            if let current = best, !candidates[index].isMoreSpecific(than: candidates[current]) {
                continue
            }
            best = index
        }
        return best
    }

    /// Removes one registration.
    ///
    /// Other registrations, including those for the same pattern, keep
    /// working. Unregistering an unknown or already-removed identifier does
    /// nothing. Copies of the router are unaffected.
    ///
    /// - Parameter registration: The identifier returned when registering.
    public mutating func unregister(_ registration: PathwayRegistrationID) {
        handlers.removeAll { $0.id == registration }
    }

    /// Removes every registered handler.
    ///
    /// This does not change ``baseHost``, ``allowedSchemes``, or ``fallback``.
    public mutating func reset() {
        handlers.removeAll()
    }

    /// Returns the patterns declared by registered handlers.
    ///
    /// - Returns: Registered patterns in ascending lexical order.
    public func registeredPatterns() -> [String] {
        handlers.map(\.handler.pattern).sorted()
    }

    /// Returns the exact hosts declared by host-specific registrations.
    ///
    /// - Returns: Registered hosts, lowercased, in ascending lexical order. This does not
    ///   include ``baseHost``.
    public func registeredHosts() -> [String] {
        handlers.compactMap(\.handler.host).sorted()
    }
}
