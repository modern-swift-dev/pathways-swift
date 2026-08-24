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

    /// The handler
    private let handler: @MainActor @Sendable ([String: String]) -> Void

    /// Flag for fragment params handling
    private let supportFragmentParams: Bool

    /// The path matching behavior.
    private let matching: PathwayMatchPolicy

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
        handler: @MainActor @Sendable @escaping ([String: String]) -> Void
    ) {
        self.host = host
        self.path = path
        self.matching = matching
        self.supportFragmentParams = supportFragmentParams
        self.handler = handler
    }

    func canHandle(_ url: URL) -> Bool {
        if let host, url.host != host {
            return false
        }

        var candidatePath = url.path
        if candidatePath.hasPrefix("//") {
            candidatePath = String(candidatePath[candidatePath.index(after: candidatePath.startIndex) ..< candidatePath.endIndex])
        }

        if let fragment = url.fragment, !fragment.isEmpty {
            let parts = fragment.split(separator: "?")
            candidatePath = "\(candidatePath)/#\(parts[0])"
        }

        return switch matching {
            case .prefix:
                candidatePath.hasPrefix(path)
            case .exact:
                candidatePath == path
        }
    }

    /// Handle the URL using the callback.
    @MainActor func handle(url: URL) throws {
        handler(supportFragmentParams ? url.allParams.asDictionary : url.queryParams.asDictionary)
    }
}
