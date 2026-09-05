import Foundation

/// An implementation that takes a sendable callback
struct PathwayPatternHandler<T: Pathway>: PathwayHandling {

    var pattern: String {
        T.pattern
    }

    let host: String?

    /// The handler
    private let handler: @MainActor @Sendable (T, [String: String]) -> Void

    /// Flag for fragment params handling
    private let supportFragmentParams: Bool

    /// The path matching behavior.
    private let matching: PathwayMatchPolicy

    /// The initializer
    /// - parameter host: If supplied, the host of the URL is validated.
    /// - parameter supportFragmentParams: True if you wish to support experimental fragment support
    /// - parameter handler: The handler
    init(
        host: String? = nil,
        matching: PathwayMatchPolicy = .prefix,
        supportFragmentParams: Bool = false,
        _ handler: @MainActor @Sendable @escaping (T, [String: String]) -> Void
    ) {
        self.host = host
        self.matching = matching
        self.supportFragmentParams = supportFragmentParams
        self.handler = handler
    }

    func canHandle(host candidateHost: String, path: String) -> Bool {
        if let host, candidateHost != host {
            return false
        }

        return PathwayMatcher(pattern: T.pattern, matching: matching).matches(path)
    }

    /// Handle the URL using the callback. Throwing if the url could not be succesfully decoded
    @MainActor func handle(url: URL, components: [String]) throws {
        let result = try PathwayDecoder.shared.decodeMatched(T.self, from: url, pattern: T.pattern, components: components)
        handler(result, supportFragmentParams ? url.allParams.asDictionary : url.queryParams.asDictionary)
    }
}
