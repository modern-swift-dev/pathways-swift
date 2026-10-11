#if canImport(Combine)
    import Combine
#endif
import Foundation

/// Encodes flat ``PathwayPatternProvider`` values as URL paths.
///
/// The encoder substitutes the pattern's `:` placeholders with the Codable
/// values and percent-encodes values used in path components. Coding keys
/// that are not pattern placeholders are written as query items, in encoding
/// order.
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
    /// - Returns: A percent-encoded path beginning with `/`, followed by a
    ///   query string when the value has non-placeholder fields.
    /// - Throws: ``PathwayError/notEncodable(key:value:)`` when `value` does
    ///   not provide a compatible pattern, leaves a placeholder unfilled
    ///   (including an omitted optional value), fills one with an empty or
    ///   explicit `nil` value, or cannot be represented by it; throws
    ///   ``PathwayError/unsupported`` for nested or unkeyed containers.
    public func encode(_ value: some Encodable) throws -> String {
        guard let encodableType = value as? (any PathwayPatternProvider) else {
            throw PathwayError.notEncodable(key: nil, value: nil)
        }

        let encoder = PathwayEncoderImpl(pattern: type(of: encodableType).pattern)
        try value.encode(to: encoder)
        return try encoder.result
    }

    /// Encodes a value as a URL relative to a base URL.
    ///
    /// - Parameters:
    ///   - value: A flat Encodable value that also conforms to
    ///     ``PathwayPatternProvider``.
    ///   - relativeTo: The base URL used to resolve the encoded path.
    /// - Returns: The resolved URL, or `nil` when Foundation cannot construct it.
    /// - Throws: ``PathwayError/notEncodable(key:value:)`` when `value` does
    ///   not provide a compatible pattern, leaves a placeholder unfilled
    ///   (including an omitted optional value), fills one with an empty or
    ///   explicit `nil` value, or cannot be represented by it; throws
    ///   ``PathwayError/unsupported`` for nested or unkeyed containers.
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

    var isUnsupported = false

    private var pattern: [String]
    private var placeholderIndices: [String: [Int]] = [:]
    private var queryItems: [String] = []

    func replace(key: String, value: String) throws {
        guard !isUnsupported else {
            throw PathwayError.unsupported
        }
        guard placeholderIndices[key] != nil else {
            try appendQueryItem(key: key, value: value)
            return
        }
        // An empty component would produce a path the decoder cannot match.
        guard !value.isEmpty,
              let index = placeholderIndices[key]?.last,
              let encoded = value.addingPercentEncoding(withAllowedCharacters: .pathwayComponentAllowed) else {
            throw PathwayError.notEncodable(key: key, value: value)
        }

        placeholderIndices[key]?.removeLast()
        pattern[index] = encoded
    }

    /// Unlike a path component, a query value may be empty.
    private func appendQueryItem(key: String, value: String) throws {
        guard let name = key.addingPercentEncoding(withAllowedCharacters: .pathwayQueryAllowed),
              let encoded = value.addingPercentEncoding(withAllowedCharacters: .pathwayQueryAllowed) else {
            throw PathwayError.notEncodable(key: key, value: value)
        }
        queryItems.append("\(name)=\(encoded)")
    }

    var result: String {
        get throws {
            guard !isUnsupported else {
                throw PathwayError.unsupported
            }
            let unfilled = placeholderIndices.flatMap { key, indices in indices.map { (index: $0, key: key) } }
            if let first = unfilled.min(by: { $0.index < $1.index }) {
                throw PathwayError.notEncodable(key: first.key, value: nil)
            }
            let path = "/\(pattern.joined(separator: "/"))"
            return queryItems.isEmpty ? path : "\(path)?\(queryItems.joined(separator: "&"))"
        }
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
        if !codingPath.isEmpty {
            isUnsupported = true
        }
        return KeyedEncodingContainer(PathwayKeyedEncodingContainer(parent: self))
    }

    func unkeyedContainer() -> any UnkeyedEncodingContainer {
        isUnsupported = true
        return UnsupportedUnkeyedEncodingContainer(parent: self)
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
        guard !parent.isUnsupported else {
            throw PathwayError.unsupported
        }
        guard let key = codingPath.last else {
            throw PathwayError.notFound(key: nil)
        }
        try parent.replace(key: key.stringValue, value: value.description)
    }

    /// A path component cannot represent nil.
    func encodeNil() throws {
        throw PathwayError.notEncodable(key: codingPath.last?.stringValue, value: nil)
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
        throw PathwayError.notEncodable(key: codingPath.last?.stringValue, value: nil)
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

    /// A path component cannot represent nil.
    func encodeNil(forKey key: Key) throws {
        throw PathwayError.notEncodable(key: key.stringValue, value: nil)
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
            try ISO8601DateFormatter.pathwayString(from: value).encode(to: parent)
            return
        }

        try value.encode(to: parent)
    }

    func nestedContainer<NestedKey: CodingKey>(keyedBy _: NestedKey.Type, forKey _: Key) -> KeyedEncodingContainer<NestedKey> {
        parent.isUnsupported = true
        return parent.container(keyedBy: NestedKey.self)
    }

    func nestedUnkeyedContainer(forKey _: Key) -> any UnkeyedEncodingContainer {
        parent.unkeyedContainer()
    }

    func superEncoder() -> any Encoder {
        parent.isUnsupported = true
        return parent
    }

    func superEncoder(forKey _: Key) -> any Encoder {
        parent.isUnsupported = true
        return parent
    }

}

private struct UnsupportedUnkeyedEncodingContainer: UnkeyedEncodingContainer {
    let parent: PathwayEncoderImpl
    var codingPath: [any CodingKey] {
        parent.codingPath
    }

    var count: Int {
        0
    }

    mutating func encodeNil() throws {
        throw PathwayError.unsupported
    }

    mutating func encode(_: some Encodable) throws {
        throw PathwayError.unsupported
    }

    mutating func nestedContainer<NestedKey: CodingKey>(keyedBy: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> {
        parent.container(keyedBy: keyedBy)
    }

    mutating func nestedUnkeyedContainer() -> any UnkeyedEncodingContainer {
        self
    }

    mutating func superEncoder() -> any Encoder {
        parent
    }
}
