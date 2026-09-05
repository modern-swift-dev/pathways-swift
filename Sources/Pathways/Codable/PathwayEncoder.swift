#if canImport(Combine)
import Combine
#endif
import Foundation

/// Encodes flat ``PathwayPatternProvider`` values as URL paths.
///
/// The encoder substitutes the pattern's `:` placeholders with the Codable
/// values and percent-encodes values used in path components.
///
/// - Important: Values must conform to both `Encodable` and
///   ``PathwayPatternProvider`` at runtime. Pathways supports only flat Codable
///   models.
public final class PathwayEncoder: Sendable {

    /// A shared encoder instance.
    public static let shared = PathwayEncoder()

    /// Creates a deep-link encoder.
    public init() {}

    /// Encodes a value as the path defined by its pattern.
    ///
    /// - Parameter value: A flat Encodable value that also conforms to
    ///   ``PathwayPatternProvider``.
    /// - Returns: A percent-encoded path beginning with `/`.
    /// - Throws: ``PathwayError/notEncodable`` when `value` does not
    ///   provide a compatible pattern or cannot be represented by it.
    public func encode(_ value: some Encodable) throws -> String {
        guard let encodableType = value as? (any PathwayPatternProvider) else {
            throw PathwayError.notEncodable
        }

        let encoder = PathwayEncoderImpl(pattern: type(of: encodableType).pattern)
        try value.encode(to: encoder)
        return encoder.result
    }

    /// Encodes a value as a URL relative to a base URL.
    ///
    /// - Parameters:
    ///   - value: A flat Encodable value that also conforms to
    ///     ``PathwayPatternProvider``.
    ///   - relativeTo: The base URL used to resolve the encoded path.
    /// - Returns: The resolved URL, or `nil` when Foundation cannot construct it.
    /// - Throws: ``PathwayError/notEncodable`` when `value` does not
    ///   provide a compatible pattern or cannot be represented by it.
    public func encode(_ value: some Encodable, relativeTo: URL) throws -> URL? {
        let path = try encode(value)
        return URL(string: path, relativeTo: relativeTo)
    }
}

#if canImport(Combine)
extension PathwayEncoder: TopLevelEncoder {
    /// The output type produced by this top-level encoder.
    public typealias Output = String
}
#endif

/// Internal implementation of the encoder, that actually does the parsing, and validations
private class PathwayEncoderImpl: Encoder {
    var codingPath: [any CodingKey] = []

    var userInfo: [CodingUserInfoKey: Any] = [:]

    private var pattern: [String]
    private var placeholderIndices: [String: [Int]] = [:]

    func replace(key: String, value: String) throws {
        guard let index = placeholderIndices[key]?.last,
              let value = value.addingPercentEncoding(withAllowedCharacters: .pathwayComponentAllowed) else {
            throw PathwayError.notEncodable
        }

        placeholderIndices[key]?.removeLast()
        pattern[index] = value
    }

    var result: String {
        "/\(pattern.joined(separator: "/"))"
    }

    init(pattern: String) {
        self.pattern = pattern.split(separator: "/").map { String($0) }
        // Reverse order lets each encoded key consume its first remaining
        // placeholder in constant time without searching substituted values.
        for index in self.pattern.indices.reversed() {
            let component = self.pattern[index]
            if component.hasPrefix(":") {
                placeholderIndices[String(component.dropFirst()), default: []].append(index)
            }
        }
    }

    func container<Key: CodingKey>(keyedBy _: Key.Type) -> KeyedEncodingContainer<Key> {
        KeyedEncodingContainer(PathwayKeyedEncodingContainer(parent: self))
    }

    func unkeyedContainer() -> any UnkeyedEncodingContainer {
        fatalError("Unsupported")
    }

    func singleValueContainer() -> any SingleValueEncodingContainer {
        PathwaySingleValueEncodingContainer(parent: self)
    }
}

private struct PathwaySingleValueEncodingContainer: SingleValueEncodingContainer {
    var codingPath: [any CodingKey] {
        get {
            parent.codingPath
        }

        nonmutating set {
            parent.codingPath = newValue
        }
    }

    private let parent: PathwayEncoderImpl

    init(parent: PathwayEncoderImpl) {
        self.parent = parent
    }

    private func rawEncode(_ value: some LosslessStringConvertible) throws {
        guard let key = codingPath.last else {
            throw PathwayError.notFound
        }
        try parent.replace(key: key.stringValue, value: value.description)
    }

    func encodeNil() throws {
        try rawEncode("nil")
    }

    func encode(_ value: Bool) throws {
        try rawEncode(value)
    }

    func encode(_ value: String) throws {
        try rawEncode(value)
    }

    func encode(_ value: Double) throws {
        try rawEncode(value)
    }

    func encode(_ value: Float) throws {
        try rawEncode(value)
    }

    func encode(_ value: Int) throws {
        try rawEncode(value)
    }

    func encode(_ value: Int8) throws {
        try rawEncode(value)
    }

    func encode(_ value: Int16) throws {
        try rawEncode(value)
    }

    func encode(_ value: Int32) throws {
        try rawEncode(value)
    }

    func encode(_ value: Int64) throws {
        try rawEncode(value)
    }

    func encode(_ value: UInt) throws {
        try rawEncode(value)
    }

    func encode(_ value: UInt8) throws {
        try rawEncode(value)
    }

    func encode(_ value: UInt16) throws {
        try rawEncode(value)
    }

    func encode(_ value: UInt32) throws {
        try rawEncode(value)
    }

    func encode(_ value: UInt64) throws {
        try rawEncode(value)
    }

    func encode(_: some Encodable) throws {
        throw PathwayError.notEncodable
    }
}

private struct PathwayKeyedEncodingContainer<Key: CodingKey>: KeyedEncodingContainerProtocol {
    var codingPath: [any CodingKey] {
        get {
            parent.codingPath
        }

        nonmutating set {
            parent.codingPath = newValue
        }
    }

    private let parent: PathwayEncoderImpl

    private func rawEncode(value: some LosslessStringConvertible, key: Key) throws {
        try parent.replace(key: key.stringValue, value: value.description)
    }

    init(parent: PathwayEncoderImpl) {
        self.parent = parent
    }

    func encodeNil(forKey key: Key) throws {
        try rawEncode(value: "nil", key: key)
    }

    func encode(_ value: Bool, forKey key: Key) throws {
        try rawEncode(value: value, key: key)
    }

    func encode(_ value: String, forKey key: Key) throws {
        try rawEncode(value: value, key: key)
    }

    func encode(_ value: Double, forKey key: Key) throws {
        try rawEncode(value: value, key: key)
    }

    func encode(_ value: Float, forKey key: Key) throws {
        try rawEncode(value: value, key: key)
    }

    func encode(_ value: Int, forKey key: Key) throws {
        try rawEncode(value: value, key: key)
    }

    func encode(_ value: Int8, forKey key: Key) throws {
        try rawEncode(value: value, key: key)
    }

    func encode(_ value: Int16, forKey key: Key) throws {
        try rawEncode(value: value, key: key)
    }

    func encode(_ value: Int32, forKey key: Key) throws {
        try rawEncode(value: value, key: key)
    }

    func encode(_ value: Int64, forKey key: Key) throws {
        try rawEncode(value: value, key: key)
    }

    func encode(_ value: UInt, forKey key: Key) throws {
        try rawEncode(value: value, key: key)
    }

    func encode(_ value: UInt8, forKey key: Key) throws {
        try rawEncode(value: value, key: key)
    }

    func encode(_ value: UInt16, forKey key: Key) throws {
        try rawEncode(value: value, key: key)
    }

    func encode(_ value: UInt32, forKey key: Key) throws {
        try rawEncode(value: value, key: key)
    }

    func encode(_ value: UInt64, forKey key: Key) throws {
        try rawEncode(value: value, key: key)
    }

    func encode(_ value: some Encodable, forKey key: Key) throws {
        codingPath.append(key)
        defer { codingPath.removeLast() }

        if let value = value as? UUID {
            try value.uuidString.encode(to: parent)
            return
        }

        if let value = value as? Date {
            try ISO8601DateFormatter.noFractionalSeconds.string(from: value).encode(to: parent)
            return
        }

        try value.encode(to: parent)
    }

    func nestedContainer<NestedKey: CodingKey>(keyedBy _: NestedKey.Type, forKey _: Key) -> KeyedEncodingContainer<NestedKey> {
        fatalError("unsupported")
    }

    func nestedUnkeyedContainer(forKey _: Key) -> any UnkeyedEncodingContainer {
        fatalError("unsupported")
    }

    func superEncoder() -> any Encoder {
        fatalError("unsupported")
    }

    func superEncoder(forKey _: Key) -> any Encoder {
        fatalError("unsupported")
    }

}
