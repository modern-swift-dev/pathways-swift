/// Errors reported while encoding or decoding a deep-link model.
///
/// Each case identifies the kind of failure. Where one exists, the associated
/// values name the failing `key` (a pattern placeholder or, for other coding
/// keys, a query parameter) and the offending `value`. Match on the kind
/// alone with a pattern such as `case .notDecodable:`.
public enum PathwayError: Error, Equatable, CustomStringConvertible {

    /// The operation requires a Codable feature Pathways does not support.
    ///
    /// For example, nested or unkeyed containers are unsupported.
    case unsupported

    /// The requested type or a path component could not be decoded.
    ///
    /// - Parameters:
    ///   - key: The placeholder or query parameter whose value failed to
    ///     convert, or `nil` when the requested type cannot be decoded as a
    ///     route.
    ///   - value: The raw path component or query value that failed to
    ///     convert, if any.
    case notDecodable(key: String?, value: String?)

    /// A value could not be encoded as the path described by its pattern.
    ///
    /// - Parameters:
    ///   - key: The placeholder or query parameter that could not be written,
    ///     or `nil` when the value cannot be encoded as a route.
    ///   - value: The value that could not be written, or `nil` when the
    ///     placeholder was left unfilled or given an explicit `nil`.
    case notEncodable(key: String?, value: String?)

    /// The URL path does not match the model's pattern.
    case invalidURL

    /// A required placeholder, path value, or query parameter is absent.
    ///
    /// - Parameter key: The placeholder or query parameter without a value,
    ///   or `nil` when no coding key identifies it.
    case notFound(key: String?)

    /// A readable description of the failure, suitable for logging.
    public var description: String {
        switch self {
            case .unsupported:
                "Pathways supports only flat Codable models; nested and unkeyed containers are unsupported."
            case let .notDecodable(key?, value?):
                "Cannot decode key \"\(key)\" from \"\(value)\"."
            case let .notDecodable(key?, nil):
                "Cannot decode key \"\(key)\"."
            case .notDecodable:
                "The value cannot be decoded as a route."
            case let .notEncodable(key?, value?):
                "Cannot encode \"\(value)\" for key \"\(key)\"."
            case let .notEncodable(key?, nil):
                "Cannot encode a value for key \"\(key)\"."
            case .notEncodable:
                "The value cannot be encoded as a route."
            case .invalidURL:
                "The URL path does not match the route pattern."
            case let .notFound(key?):
                "No value for key \"\(key)\"."
            case .notFound:
                "No value for the requested key."
        }
    }
}
