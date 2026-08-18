import Foundation
import Pathways
import Testing

// swiftlint:disable force_unwrapping
@Suite(.serialized) struct PathwayDecoderTests {

    @Test func invalidDecoding() throws {
        let url = try #require(URL(string: "https://localhost:8080/user/666"))

        let decoder = PathwayDecoder()
        #expect(throws: (any Error).self) {
            try decoder.decode(TestInvalidPathway.self, from: url)
        }
    }

    @Test func decoding1Value() throws {
        let url = try #require(URL(string: "https://localhost:8080/user/666"))

        let decoder = PathwayDecoder()
        let result = try decoder.decode(TestSingleFieldPathway.self, from: url)
        #expect(result.id == 666)
    }

    @Test func decoding2Value() throws {
        let url = try #require(URL(string: "https://localhost:8080/user/666/picture/\(UInt64.max)"))

        let decoder = PathwayDecoder()
        let result = try decoder.decode(TestMultiFieldTypesPathway.self, from: url)
        #expect(result.id == 666)
        #expect(result.pictureId == UInt64.max)
    }

    @Test func decoding2ValueString() throws {
        let url = try #require(URL(string: "https://localhost:8080/user/666/type/admin"))

        let decoder = PathwayDecoder()
        let result = try decoder.decode(TestMultiFieldPathway.self, from: url)
        #expect(result.id == 666)
        #expect(result.type == "admin")
    }

    @Test func decoding2ValueEnum() throws {
        let url = try #require(URL(string: "https://localhost:8080/user/666/type/admin"))

        let decoder = PathwayDecoder()
        let result = try decoder.decode(TestEnumPathway.self, from: url)
        #expect(result.userId == 666)
        #expect(result.type == .admin)
    }

    @Test func decodingAll() throws {
        let url = try #require(URL(string: "https://localhost:8080/1/2/3/4/5/6/7/8/9/10/1.25/10.25/true/t/admin"))

        let decoder = PathwayDecoder()
        let result = try decoder.decode(TestAllTypePathway.self, from: url)

        #expect(result.int == 1)
        #expect(result.int8 == 2)
        #expect(result.int16 == 3)
        #expect(result.int32 == 4)
        #expect(result.int64 == 5)
        #expect(result.uint == 6)
        #expect(result.uint8 == 7)
        #expect(result.uint16 == 8)
        #expect(result.uint32 == 9)
        #expect(result.uint64 == 10)
        #expect(result.float == 1.25)
        #expect(result.double == 10.25)
        #expect(result.bool == true)
        #expect(result.str == "t")
        #expect(result.enumerated == .admin)
    }
}
