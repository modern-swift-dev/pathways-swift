#if canImport(Combine)
import Combine
#endif
import Foundation

/// Decodes URL paths into flat ``PathwayPatternProvider`` values.
///
/// The decoder validates the URL path against the type's pattern before using
/// its placeholders to initialize the value.
///
/// - Important: Values must conform to both `Decodable` and
///   ``PathwayPatternProvider`` at runtime. Pathways supports only flat Codable
///   models.
public final class PathwayDecoder: Sendable {

    /// A shared decoder instance.
    public static let shared = PathwayDecoder()

    /// Creates a deep-link decoder.
    public init() {}

    /// Decodes a URL path into a value of the requested type.
    ///
    /// - Parameters:
    ///   - type: The destination type, which must also conform to
    ///     ``PathwayPatternProvider``.
    ///   - from: The URL whose path should be decoded.
    /// - Returns: A value initialized from path components matched by `type`'s
    ///   pattern.
    /// - Throws: ``PathwayError/notDecodable`` when the type or a path
    ///   component cannot be decoded, or ``PathwayError/invalidURL`` when
    ///   the URL path does not match the pattern.
    public func decode<T: Decodable>(_ type: T.Type, from: URL) throws -> T {
        guard let decodableType = type as? any PathwayPatternProvider.Type else {
            throw PathwayError.notDecodable
        }

        let components = from.pathwayPathComponents
        let path = components.pathwayMatchingPath

        guard PathwayMatcher(pattern: decodableType.pattern, matching: .prefix).matches(path) else {
            throw PathwayError.invalidURL
        }

        return try decodeMatched(type, from: from, pattern: decodableType.pattern, components: components)
    }

    /// The router has already validated the pattern against these components.
    func decodeMatched<T: Decodable>(_ type: T.Type, from: URL, pattern: String, components: [String]) throws -> T {
        guard from.host != nil, from.scheme != nil else {
            throw PathwayError.notDecodable
        }

        let decoder = PathwayDecoderImpl(pattern: pattern, components: components)
        return try type.init(from: decoder)
    }
}

#if canImport(Combine)
extension PathwayDecoder: TopLevelDecoder {
    /// The input type accepted by this top-level decoder.
    public typealias Input = URL
}
#endif

/// Internal implementation of the decoder, that actually does the parsing, and validations
private final class PathwayDecoderImpl: Decoder {

    /// The coding path
    var codingPath: [any CodingKey] = []

    /// The User Info dictionary
    var userInfo: [CodingUserInfoKey: Any] = [:]

    /// Keep the first value for each placeholder, matching duplicate-key behavior.
    private let componentsByKey: [String: String]

    func keys<Key: CodingKey>(_: Key.Type) -> [Key] {
        componentsByKey.compactMap { $0.value.isEmpty ? nil : Key(stringValue: $0.key) }
    }

    init(pattern: String, components: [String]) {
        var values: [String: String] = [:]
        for (index, component) in pattern.split(separator: "/").enumerated() where component.hasPrefix(":") {
            let key = String(component.dropFirst())
            if values[key] == nil, components.indices.contains(index) {
                values[key] = components[index]
            }
        }
        componentsByKey = values
    }

    func container<Key: CodingKey>(keyedBy _: Key.Type) throws -> KeyedDecodingContainer<Key> {
        KeyedDecodingContainer(PathwayKeyedDecodingContainer(parent: self))
    }

    func unkeyedContainer() throws -> any UnkeyedDecodingContainer {
        throw PathwayError.unsupported
    }

    func singleValueContainer() throws -> any SingleValueDecodingContainer {
        PathwaySingleValueDecodingContainer(parent: self)
    }

    /// A method that can decode any lossless string convertible
    func rawDecode<T: LosslessStringConvertible>(for key: any CodingKey) throws -> T {
        let pathComponent = try component(for: key)
        guard let value = T(pathComponent) else {
            throw PathwayError.notDecodable
        }

        return value
    }

    func component(for key: any CodingKey) throws -> String {
        guard let value = componentsByKey[key.stringValue], !value.isEmpty else {
            throw PathwayError.notFound
        }
        return value
    }

}

private struct PathwayKeyedDecodingContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {
    var codingPath: [any CodingKey] {
        get {
            parent.codingPath
        }

        nonmutating set {
            parent.codingPath = newValue
        }
    }

    var allKeys: [Key] {
        parent.keys(Key.self)
    }

    private let parent: PathwayDecoderImpl

    init(parent: PathwayDecoderImpl) {
        self.parent = parent
    }

    func contains(_ key: Key) -> Bool {
        (try? parent.component(for: key)) != nil
    }

    func decodeNil(forKey key: Key) throws -> Bool {
        _ = try parent.component(for: key)
        return false
    }

    func decode(_: Bool.Type, forKey key: Key) throws -> Bool {
        try parent.rawDecode(for: key)
    }

    func decode(_: String.Type, forKey key: Key) throws -> String {
        try parent.rawDecode(for: key)
    }

    func decode(_: Double.Type, forKey key: Key) throws -> Double {
        try parent.rawDecode(for: key)
    }

    func decode(_: Float.Type, forKey key: Key) throws -> Float {
        try parent.rawDecode(for: key)
    }

    func decode(_: Int.Type, forKey key: Key) throws -> Int {
        try parent.rawDecode(for: key)
    }

    func decode(_: Int8.Type, forKey key: Key) throws -> Int8 {
        try parent.rawDecode(for: key)
    }

    func decode(_: Int16.Type, forKey key: Key) throws -> Int16 {
        try parent.rawDecode(for: key)
    }

    func decode(_: Int32.Type, forKey key: Key) throws -> Int32 {
        try parent.rawDecode(for: key)
    }

    func decode(_: Int64.Type, forKey key: Key) throws -> Int64 {
        try parent.rawDecode(for: key)
    }

    func decode(_: UInt.Type, forKey key: Key) throws -> UInt {
        try parent.rawDecode(for: key)
    }

    func decode(_: UInt8.Type, forKey key: Key) throws -> UInt8 {
        try parent.rawDecode(for: key)
    }

    func decode(_: UInt16.Type, forKey key: Key) throws -> UInt16 {
        try parent.rawDecode(for: key)
    }

    func decode(_: UInt32.Type, forKey key: Key) throws -> UInt32 {
        try parent.rawDecode(for: key)
    }

    func decode(_: UInt64.Type, forKey key: Key) throws -> UInt64 {
        try parent.rawDecode(for: key)
    }

    func decode<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T {
        codingPath.append(key)
        defer { codingPath.removeLast() }

        if T.self == Date.self {
            let component = try parent.component(for: key)
            guard let date = ISO8601DateFormatter.pathwayDate(from: component) as? T else {
                throw PathwayError.notDecodable
            }
            return date
        }

        return try type.init(from: parent)

    }

    func nestedContainer<NestedKey: CodingKey>(keyedBy _: NestedKey.Type, forKey _: Key) throws -> KeyedDecodingContainer<NestedKey> {
        throw PathwayError.unsupported
    }

    func nestedUnkeyedContainer(forKey _: Key) throws -> any UnkeyedDecodingContainer {
        throw PathwayError.unsupported
    }

    func superDecoder() throws -> any Decoder {
        throw PathwayError.unsupported
    }

    func superDecoder(forKey _: Key) throws -> any Decoder {
        throw PathwayError.unsupported
    }
}

private struct PathwaySingleValueDecodingContainer: SingleValueDecodingContainer {

    var codingPath: [any CodingKey] {
        get {
            parent.codingPath
        }

        nonmutating set {
            parent.codingPath = newValue
        }
    }

    private let parent: PathwayDecoderImpl

    init(parent: PathwayDecoderImpl) {
        self.parent = parent
    }

    private func rawDecode<T: LosslessStringConvertible>() throws -> T {
        if let key = codingPath.last {
            return try parent.rawDecode(for: key)
        }
        throw PathwayError.notFound
    }

    func decodeNil() -> Bool {
        false
    }

    func decode(_: Bool.Type) throws -> Bool {
        try rawDecode()
    }

    func decode(_: String.Type) throws -> String {
        try rawDecode()
    }

    func decode(_: Double.Type) throws -> Double {
        try rawDecode()
    }

    func decode(_: Float.Type) throws -> Float {
        try rawDecode()
    }

    func decode(_: Int.Type) throws -> Int {
        try rawDecode()
    }

    func decode(_: Int8.Type) throws -> Int8 {
        try rawDecode()
    }

    func decode(_: Int16.Type) throws -> Int16 {
        try rawDecode()
    }

    func decode(_: Int32.Type) throws -> Int32 {
        try rawDecode()
    }

    func decode(_: Int64.Type) throws -> Int64 {
        try rawDecode()
    }

    func decode(_: UInt.Type) throws -> UInt {
        try rawDecode()
    }

    func decode(_: UInt8.Type) throws -> UInt8 {
        try rawDecode()
    }

    func decode(_: UInt16.Type) throws -> UInt16 {
        try rawDecode()
    }

    func decode(_: UInt32.Type) throws -> UInt32 {
        try rawDecode()
    }

    func decode(_: UInt64.Type) throws -> UInt64 {
        try rawDecode()
    }

    func decode<T: Decodable>(_ type: T.Type) throws -> T {
        try type.init(from: parent)
    }
}
