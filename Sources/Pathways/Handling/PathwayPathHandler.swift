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
    private let encodedPath: String

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
        // Normalize like incoming URLs so leading, trailing, and repeated slashes don't matter.
        encodedPath = path.split(separator: "/").map(String.init).pathwayMatchingPath
        self.matching = matching
        self.supportFragmentParams = supportFragmentParams
        self.handler = handler
    }

    func canHandle(host candidateHost: String, path candidatePath: String) -> Bool {
        if let host, candidateHost != host {
            return false
        }

        return switch matching {
            case .prefix:
                candidatePath.hasPrefix(encodedPath)
            case .exact:
                candidatePath == encodedPath
        }
    }

    /// Handle the URL using the callback.
    @MainActor func handle(url: URL, components _: [String]) throws {
        handler(url.pathwayParameters(supportFragmentParams: supportFragmentParams))
    }
}
