import Foundation
import Pathways
import Testing

struct EncoderOptimizationTests {
    private struct InspectedValue: Encodable {
        let expectedKey: String

        func encode(to encoder: any Encoder) throws {
            #expect(encoder.codingPath.map(\.stringValue) == [expectedKey])
            var container = encoder.singleValueContainer()
            try container.encode(expectedKey)
        }
    }

    private struct InspectedRoute: PathwayEncodable {
        static let pattern = "/:number/:first/:second"

        enum CodingKeys: String, CodingKey {
            case number
            case first
            case second
            case missing
        }

        func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(42, forKey: .number)
            #expect(container.codingPath.isEmpty)
            try container.encode(InspectedValue(expectedKey: "first"), forKey: .first)
            #expect(container.codingPath.isEmpty)
            #expect(throws: PathwayError.notEncodable) {
                try container.encode(InspectedValue(expectedKey: "missing"), forKey: .missing)
            }
            #expect(container.codingPath.isEmpty)
            try container.encode(InspectedValue(expectedKey: "second"), forKey: .second)
            #expect(encoder.codingPath.isEmpty)
        }
    }

    @Test func siblingsAndErrorsDoNotAccumulateCodingPaths() throws {
        #expect(try PathwayEncoder.shared.encode(InspectedRoute()) == "/42/first/second")
    }

    private struct PlaceholderValueRoute: PathwayEncodable {
        static let pattern = "/:first/:second"
        let first = ":second"
        let second = "value"
    }

    @Test func encodedValuesAreNotTreatedAsPlaceholders() throws {
        #expect(try PathwayEncoder.shared.encode(PlaceholderValueRoute()) == "/:second/value")
    }

    private struct RepeatedPlaceholderRoute: PathwayEncodable {
        static let pattern = "/:value/:value"

        enum CodingKeys: String, CodingKey {
            case value
        }

        func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(1, forKey: .value)
            try container.encode(2, forKey: .value)
            #expect(throws: PathwayError.notEncodable) {
                try container.encode(3, forKey: .value)
            }
        }
    }

    @Test func repeatedPlaceholdersAreConsumedInPatternOrder() throws {
        #expect(try PathwayEncoder.shared.encode(RepeatedPlaceholderRoute()) == "/1/2")
    }

}
