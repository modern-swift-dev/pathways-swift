import Foundation

/// A protocol for the handlers
protocol PathwayHandling: Sendable {

    /// The pattern
    var pattern: String { get }

    /// The host
    var host: String? { get }

    /// Return true if the url is supported by this handler
    func canHandle(_ url: URL) -> Bool

    /// Execute the logic of the handler
    @MainActor func handle(url: URL) throws
}
