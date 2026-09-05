import Foundation
import Pathways
import Testing

struct DecoderLookupTests {
    private struct WideRoute: PathwayDecodable {
        static let pattern = (0 ..< 128).map { "/:key\($0)" }.joined()
        let values: [String]

        struct Key: CodingKey {
            let stringValue: String
            let intValue: Int? = nil
            init?(stringValue: String) {
                self.stringValue = stringValue
            }

            init?(intValue _: Int) {
                nil
            }
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: Key.self)
            #expect(container.allKeys.count == 128)
            values = try (0 ..< 128).map { index in
                let key = try #require(Key(stringValue: "key\(index)"))
                #expect(container.contains(key))
                return try container.decode(String.self, forKey: key)
            }
        }
    }

    private struct DuplicateRoute: PathwayDecodable {
        static let pattern = "/:value/:value"
        let value: String
    }

    @Test func wideRoutesDecodeEveryKey() throws {
        let values = (0 ..< 128).map { "value\($0)" }
        let url = try #require(URL(string: "https://localhost/" + values.joined(separator: "/")))
        #expect(try PathwayDecoder.shared.decode(WideRoute.self, from: url).values == values)
    }

    @Test func duplicatePlaceholdersKeepTheFirstValue() throws {
        let url = try #require(URL(string: "https://localhost/first/second"))
        #expect(try PathwayDecoder.shared.decode(DuplicateRoute.self, from: url).value == "first")
        let emptyFirst = try #require(URL(string: "https://localhost///second"))
        #expect(throws: PathwayError.notFound) {
            try PathwayDecoder.shared.decode(DuplicateRoute.self, from: emptyFirst)
        }
    }
}
