import Foundation
import Pathways
import Testing

@Suite(.serialized) struct PathwayEncoderTests {

    @Test func invalidEncoding() throws {
        let encoder = PathwayEncoder()
        #expect(throws: (any Error).self) {
            try encoder.encode(TestInvalidPathway(id: 1))
        }
    }

    @Test func encoding1Value() throws {
        let encoder = PathwayEncoder()
        let value = TestSingleFieldPathway(id: 1)
        let result = try encoder.encode(value)
        #expect(result == "/user/1")
    }

    @Test func encoding2Value() throws {
        let encoder = PathwayEncoder()
        let value = TestMultiFieldTypesPathway(id: 1, pictureId: 2)
        let result = try encoder.encode(value)
        #expect(result == "/user/1/picture/2")
    }

    @Test func encoding2ValueString() throws {
        let encoder = PathwayEncoder()
        let value = TestMultiFieldPathway(id: 1, type: "admin")
        let result = try encoder.encode(value)
        #expect(result == "/user/1/type/admin")
    }

    @Test func encoding2ValueEnum() throws {
        let encoder = PathwayEncoder()
        let value = TestEnumPathway(userId: 1, type: .admin)
        let result = try encoder.encode(value)
        #expect(result == "/user/1/type/admin")
    }

    @Test func encodingAll() throws {
        let encoder = PathwayEncoder()
        let value = TestAllTypePathway(
            int: 1,
            int8: 2,
            int16: 3,
            int32: 4,
            int64: 5,
            uint: 6,
            uint8: 7,
            uint16: 8,
            uint32: 9,
            uint64: 10,
            float: 1.25,
            double: 10.25,
            bool: true,
            str: "t",
            enumerated: .admin
        )
        let result = try encoder.encode(value)
        #expect(result == "/1/2/3/4/5/6/7/8/9/10/1.25/10.25/true/t/admin")
    }
}
