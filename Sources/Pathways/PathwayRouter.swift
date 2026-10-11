import Foundation

/// A value-based router that dispatches URLs to registered handlers.
///
/// Register typed ``Pathway`` route models or path handlers, then
/// call `handle(_:)` for each incoming URL.
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
    /// URL or every matching handler declines, so `handle(_:)` returns
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
    /// for `host`, `matching`, and `supportFragmentParams`, and accept
    /// synchronous and asynchronous request handlers as well as handlers that
    /// receive the parameter dictionary, which always handle the URL.
    ///
    /// - Parameters:
    ///   - host: The URL host the handler accepts, compared case-insensitively,
    ///     or `nil` for a hostless registration.
    ///   - type: The route model whose ``PathwayPatternProvider/pattern`` is
    ///     matched and decoded.
    ///   - matching: The policy used to match the route.
    ///   - supportFragmentParams: Whether to merge query items following a
    ///     fragment route into the request's parameters and query items.
    ///   - handler: The main-actor handler invoked with the decoded route and
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
        handler: PathwayHandler<T>
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
    /// for `host`, `matching`, and `supportFragmentParams`, and accept
    /// synchronous and asynchronous request handlers as well as handlers that
    /// receive the parameter dictionary, which always handle the URL.
    ///
    /// - Parameters:
    ///   - host: The URL host the handler accepts, compared case-insensitively,
    ///     or `nil` for a hostless registration.
    ///   - path: The path the handler accepts.
    ///   - matching: The policy used to match the path.
    ///   - supportFragmentParams: Whether to merge query items following a
    ///     fragment route into the request's parameters and query items.
    ///   - handler: The main-actor handler invoked with the request. Return
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
        handler: PathwayHandler<Void>
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

    /// Handles a URL with the best matching registered synchronous handler.
    ///
    /// - Parameter url: The incoming URL to route.
    /// - Returns: `true` if a handler or the ``fallback`` handled the URL;
    ///   otherwise, `false` when the URL scheme is not allowed, the URL host
    ///   is not registered, or no handler matches or every matching handler
    ///   declines and there is no fallback. A URL without a host, such as
    ///   `myapp:///products/42`, is considered only by hostless registrations,
    ///   and only while ``baseHost`` is empty.
    /// - Throws: Any error thrown while decoding a matching typed route. A
    ///   decode error stops routing rather than falling through. Throws
    ///   ``PathwayRouterError/asyncHandlerRequiresAsyncHandle`` instead of
    ///   skipping an asynchronous handler it selects; route such URLs with
    ///   the async `handle(_:)`.
    /// - Important: When several handlers match, Pathways selects the most
    ///   specific one. At the first path component where two patterns differ,
    ///   a literal beats a `:` placeholder; otherwise the longer pattern wins,
    ///   then exact matching beats prefix matching, then a host-specific
    ///   registration beats a hostless one. Equally specific registrations
    ///   keep the first one registered. When the selected handler returns
    ///   ``PathwayHandlerResult/declined``, routing falls through to the next
    ///   handler in that order.
    @MainActor public func handle(_ url: URL) throws -> Bool {
        guard var candidates = candidates(for: url) else {
            return false
        }
        while let handler = candidates.next() {
            guard !handler.isAsync else {
                throw PathwayRouterError.asyncHandlerRequiresAsyncHandle
            }
            if try handler.handle(url: url, components: candidates.components) == .handled {
                return true
            }
        }
        return runFallback(for: url)
    }

    /// Handles a URL with the best matching registered handler, awaiting it
    /// when it is asynchronous.
    ///
    /// This runs synchronous and asynchronous handlers alike, with the same
    /// precedence, fall-through, and ``fallback`` as the synchronous
    /// `handle(_:)`.
    ///
    /// - Parameter url: The incoming URL to route.
    /// - Returns: `true` if a handler or the ``fallback`` handled the URL;
    ///   otherwise, `false` when the URL scheme is not allowed, the URL host
    ///   is not registered, or no handler matches or every matching handler
    ///   declines and there is no fallback.
    /// - Throws: Any error thrown while decoding a matching typed route. A
    ///   decode error stops routing rather than falling through.
    @MainActor public func handle(_ url: URL) async throws -> Bool {
        guard var candidates = candidates(for: url) else {
            return false
        }
        while let handler = candidates.next() {
            if try await handler.handle(url: url, components: candidates.components) == .handled {
                return true
            }
        }
        return runFallback(for: url)
    }

    /// Returns the handlers matching an admitted URL, or `nil` when its
    /// scheme or host is rejected.
    private func candidates(for url: URL) -> Candidates? {
        if let allowedSchemes {
            guard let scheme = url.scheme?.lowercased(),
                  allowedSchemes.contains(where: { $0.lowercased() == scheme }) else {
                return nil
            }
        }

        let host: String?
        if let urlHost = url.host?.lowercased(), !urlHost.isEmpty {
            guard urlHost == baseHost.lowercased() || handlers.contains(where: { $0.handler.host == urlHost }) else {
                return nil
            }
            host = urlHost
        } else {
            // A custom-scheme URL such as myapp:///products/42 has no host.
            guard url.scheme != nil, baseHost.isEmpty else {
                return nil
            }
            host = nil
        }

        let components = url.pathwayPathComponents
        return Candidates(
            components: components,
            remaining: handlers.map(\.handler).filter { $0.canHandle(host: host, components: components) }
        )
    }

    @MainActor private func runFallback(for url: URL) -> Bool {
        guard let fallback else {
            return false
        }
        fallback(PathwayRequest(url: url, supportFragmentParams: false))
        return true
    }

    /// Matching handlers, yielded most specific first.
    private struct Candidates {
        let components: [String]
        var remaining: [any PathwayHandling]

        /// Equally specific handlers keep the first one registered.
        mutating func next() -> (any PathwayHandling)? {
            var best: Int?
            for index in remaining.indices {
                if let current = best, !remaining[index].isMoreSpecific(than: remaining[current]) {
                    continue
                }
                best = index
            }
            return best.map { remaining.remove(at: $0) }
        }
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
