import Foundation

/// An implementation that takes a sendable callback
struct PathwayPatternHandler<T: Pathway>: PathwayHandling {

    var pattern: String {
        T.pattern
    }

    let host: String?

    /// The handler
    private let handler: PathwayHandler<T>

    /// Flag for fragment params handling
    private let supportFragmentParams: Bool

    /// The path matching behavior.
    private let matching: PathwayMatchPolicy
    private let initialPattern: String
    private let initialMatcher: PathwayMatcher

    /// The initializer
    /// - parameter host: If supplied, the host of the URL is validated.
    /// - parameter supportFragmentParams: True if you wish to support experimental fragment support
    /// - parameter handler: The handler
    init(
        host: String? = nil,
        matching: PathwayMatchPolicy = .prefix,
        supportFragmentParams: Bool = false,
        _ handler: PathwayHandler<T>
    ) {
        // Hosts are case-insensitive.
        self.host = host?.lowercased()
        self.matching = matching
        initialPattern = T.pattern
        initialMatcher = PathwayMatcher(pattern: initialPattern, matching: matching)
        self.supportFragmentParams = supportFragmentParams
        self.handler = handler
    }

    func canHandle(host candidateHost: String?, components: [String]) -> Bool {
        if let host, candidateHost != host {
            return false
        }

        return matcher.matches(components)
    }

    var matcher: PathwayMatcher {
        let pattern = T.pattern
        // Computed pattern providers may change after registration.
        return pattern == initialPattern ? initialMatcher : PathwayMatcher(pattern: pattern, matching: matching)
    }

    var isAsync: Bool {
        handler.isAsync
    }

    /// Handle the URL using the callback. Throwing if the url could not be successfully decoded
    @MainActor func handle(url: URL, components: [String]) throws -> PathwayHandlerResult {
        let result = try PathwayDecoder.shared.decodeMatched(T.self, from: url, pattern: T.pattern, components: components)
        return try handler(result, PathwayRequest(url: url, supportFragmentParams: supportFragmentParams))
    }

    /// Handle the URL using the callback, awaiting it when it is asynchronous.
    /// Throwing if the url could not be successfully decoded
    @MainActor func handle(url: URL, components: [String]) async throws -> PathwayHandlerResult {
        let result = try PathwayDecoder.shared.decodeMatched(T.self, from: url, pattern: T.pattern, components: components)
        return await handler(result, PathwayRequest(url: url, supportFragmentParams: supportFragmentParams))
    }
}
