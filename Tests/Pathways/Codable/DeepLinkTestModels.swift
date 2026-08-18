import Foundation
import Pathways

struct TestInvalidPathway: Codable {
    var id: Int
}

struct TestSingleFieldPathway: Pathway {
    static var pattern: String {
        "/user/:\(CodingKeys.id.stringValue)"
    }

    var id: Int
}

struct TestMultiFieldTypesPathway: Pathway {
    static var pattern: String {
        "/user/:\(CodingKeys.id.stringValue)/picture/:\(CodingKeys.pictureId.stringValue)"
    }

    var id: Int
    var pictureId: UInt64
}

struct TestMultiFieldPathway: Pathway {
    static var pattern: String {
        "/user/:\(CodingKeys.id.stringValue)/type/:\(CodingKeys.type.stringValue)"
    }

    var id: Int
    var type: String
}

enum TestEnum: String, Codable {
    case user
    case admin
    case manager
}

struct TestEnumPathway: Pathway {
    static var pattern: String {
        "/user/:\(CodingKeys.userId.stringValue)/type/:\(CodingKeys.type.stringValue)"
    }

    var userId: Int
    var type: TestEnum

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case type
    }
}

struct TestAllTypePathway: Pathway {

    static var pattern: String {

        let pattern = [
            Self.CodingKeys.int.stringValue,
            Self.CodingKeys.int8.stringValue,
            Self.CodingKeys.int16.stringValue,
            Self.CodingKeys.int32.stringValue,
            Self.CodingKeys.int64.stringValue,
            Self.CodingKeys.uint.stringValue,
            Self.CodingKeys.uint8.stringValue,
            Self.CodingKeys.uint16.stringValue,
            Self.CodingKeys.uint32.stringValue,
            Self.CodingKeys.uint64.stringValue,
            Self.CodingKeys.float.stringValue,
            Self.CodingKeys.double.stringValue,
            Self.CodingKeys.bool.stringValue,
            Self.CodingKeys.str.stringValue,
            Self.CodingKeys.enumerated.stringValue
        ].map { ":\($0)" }.joined(separator: "/")

        return "/\(pattern)"

    }

    var int: Int
    var int8: Int8
    var int16: Int16
    var int32: Int32
    var int64: Int64
    var uint: UInt
    var uint8: UInt8
    var uint16: UInt16
    var uint32: UInt32
    var uint64: UInt64
    var float: Float
    var double: Double
    var bool: Bool
    var str: String
    var enumerated: TestEnum
}
