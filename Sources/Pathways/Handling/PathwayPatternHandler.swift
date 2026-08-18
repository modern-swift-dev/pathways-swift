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

    /// The initializer
    /// - parameter host: If supplied, the host of the URL is validated.
    /// - parameter supportFragmentParams: True if you wish to support experimental fragment support
    /// - parameter handler: The handler
    init(
        host: String? = nil,
        supportFragmentParams: Bool = false,
        _ handler: @MainActor @Sendable @escaping (T, [String: String]) -> Void
    ) {
        self.host = host
        self.supportFragmentParams = supportFragmentParams
        self.handler = handler
    }

    /// The implementation for the canHandle, checking for the regex
    func canHandle(_ url: URL) -> Bool {
        if let host, url.host != host {
            return false
        }

        var path = url.path
        if path.hasPrefix("//") {
            path = String(path[path.index(after: path.startIndex) ..< path.endIndex])
        }

        if let fragment = url.fragment, !fragment.isEmpty {
            let parts = fragment.split(separator: "?")
            path = "\(path)/#\(parts[0])"
        }

        let range = NSRange(path.startIndex ..< path.endIndex, in: path)
        if let regex = T.regex, regex.numberOfMatches(in: path, range: range) == 1 {
            return true
        }

        return false
    }

    /// Handle the URL using the callback. Throwing if the url could not be succesfully decoded
    @MainActor func handle(url: URL) throws {
        let result = try PathwayDecoder.shared.decode(T.self, from: url)
        handler(result, supportFragmentParams ? url.allParams.asDictionary : url.queryParams.asDictionary)
    }
}
