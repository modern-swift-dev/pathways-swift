import Foundation

/// A handler that invokes a closure for a matching path.
struct PathwayPathHandler: PathwayHandling {

    var pattern: String {
        path
    }

    /// The Host
    let host: String?

    /// The path
    private let path: String
    let matcher: PathwayMatcher

    /// The handler
    private let handler: PathwayHandler<Void>

    /// Flag for fragment params handling
    private let supportFragmentParams: Bool

    /// The initializer
    /// - parameter host: If supplied, the host of the URL is validated.
    /// - parameter path: The url path
    /// - parameter supportFragmentParams: True if you wish to support experimental fragment support
    /// - parameter handler: The handler
    init(
        host: String? = nil,
        path: String,
        matching: PathwayMatchPolicy = .prefix,
        supportFragmentParams: Bool = false,
        handler: PathwayHandler<Void>
    ) {
        // Hosts are case-insensitive.
        self.host = host?.lowercased()
        self.path = path
        matcher = PathwayMatcher(path: path, matching: matching)
        self.supportFragmentParams = supportFragmentParams
        self.handler = handler
    }

    func canHandle(host candidateHost: String?, components: [String]) -> Bool {
        if let host, candidateHost != host {
            return false
        }
        return matcher.matches(components)
    }

    var isAsync: Bool {
        handler.isAsync
    }

    /// Handle the URL using the callback.
    @MainActor func handle(url: URL, components _: [String]) throws -> PathwayHandlerResult {
        try handler((), PathwayRequest(url: url, supportFragmentParams: supportFragmentParams))
    }

    /// Handle the URL using the callback, awaiting it when it is asynchronous.
    @MainActor func handle(url: URL, components _: [String]) async throws -> PathwayHandlerResult {
        await handler((), PathwayRequest(url: url, supportFragmentParams: supportFragmentParams))
    }
}
