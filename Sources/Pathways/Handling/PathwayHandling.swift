import Foundation

/// A protocol for the handlers
protocol PathwayHandling: Sendable {

    /// The pattern
    var pattern: String { get }

    /// The host
    var host: String? { get }

    /// The matcher for the handler's current pattern
    var matcher: PathwayMatcher { get }

    /// Return true if the url is supported by this handler.
    ///
    /// A `nil` host, from a URL without one, matches only hostless handlers.
    func canHandle(host: String?, components: [String]) -> Bool

    /// Execute the logic of the handler, reporting whether it handled the URL
    @MainActor func handle(url: URL, components: [String]) throws -> PathwayHandlerResult
}

extension PathwayHandling {
    /// Returns whether this handler should win over another that matched the same URL.
    ///
    /// Equally specific patterns prefer a host-specific registration.
    func isMoreSpecific(than other: any PathwayHandling) -> Bool {
        if matcher.isMoreSpecific(than: other.matcher) {
            return true
        }
        if other.matcher.isMoreSpecific(than: matcher) {
            return false
        }
        return host != nil && other.host == nil
    }
}
