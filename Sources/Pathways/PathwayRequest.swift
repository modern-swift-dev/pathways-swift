import Foundation

/// The URL a handler was invoked for, with its query parameters.
public struct PathwayRequest: Sendable, Equatable {

    /// The URL being routed, exactly as passed to `handle(_:)`.
    public let url: URL

    /// The query parameters merged into a dictionary.
    ///
    /// A parameter without a value maps to an empty string, and when a name
    /// repeats, the last value wins. Use ``queryItems`` to read every value.
    public let parameters: [String: String]

    /// Every query item, in URL order.
    ///
    /// Repeated names keep each value, and a parameter without a value, such
    /// as `?debug`, has a `nil` value. When the registration supports fragment
    /// parameters, items following the fragment route come after the
    /// standard query items.
    public let queryItems: [URLQueryItem]

    init(url: URL, supportFragmentParams: Bool) {
        self.url = url
        queryItems = url.pathwayQueryItems(supportFragmentParams: supportFragmentParams)
        parameters = queryItems.asDictionary
    }
}
