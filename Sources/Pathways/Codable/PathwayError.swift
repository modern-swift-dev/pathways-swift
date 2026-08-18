/// Errors reported while encoding or decoding a deep-link model.
public enum PathwayError: Error {

    /// The operation requires a Codable feature Pathways does not support.
    ///
    /// For example, nested or unkeyed containers are unsupported.
    case unsupported

    /// The requested type or a path component could not be decoded.
    case notDecodable

    /// A value could not be encoded as the path described by its pattern.
    case notEncodable

    /// The URL path does not match the model's pattern.
    case invalidURL

    /// A required placeholder or path value is absent.
    case notFound
}
