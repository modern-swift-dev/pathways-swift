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

    private struct ArrayRoute: PathwayEncodable {
        static let pattern = "/:values"
        let values: [Int]
    }

    @Test(arguments: [[], [1, 2]]) func arraysThrowInsteadOfCrashing(_ values: [Int]) throws {
        #expect(throws: PathwayError.unsupported) {
            try PathwayEncoder.shared.encode(ArrayRoute(values: values))
        }
    }

    private struct UnsupportedRoute: PathwayEncodable {
        static let pattern = "/:value"
        let kind: Kind

        enum Kind: CaseIterable { case nested, nestedArray, superclass, keyedSuperclass, arrayNested, arraySuperclass }
        enum CodingKeys: String, CodingKey { case value }

        func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch kind {
                case .nested:
                    var nested = container.nestedContainer(keyedBy: CodingKeys.self, forKey: .value)
                    try nested.encode(1, forKey: .value)
                case .nestedArray:
                    var nested = container.nestedUnkeyedContainer(forKey: .value)
                    try nested.encode(1)
                case .superclass:
                    var nested = container.superEncoder().singleValueContainer()
                    try nested.encode(1)
                case .keyedSuperclass:
                    var nested = container.superEncoder(forKey: .value).singleValueContainer()
                    try nested.encode(1)
                case .arrayNested:
                    var array = encoder.unkeyedContainer()
                    var nested = array.nestedContainer(keyedBy: CodingKeys.self)
                    try nested.encode(1, forKey: .value)
                case .arraySuperclass:
                    var array = encoder.unkeyedContainer()
                    _ = array.superEncoder()
            }
        }
    }

    @Test(arguments: UnsupportedRoute.Kind.allCases) private func unsupportedContainersThrowInsteadOfCrashing(_ kind: UnsupportedRoute.Kind) throws {
        #expect(throws: PathwayError.unsupported) {
            try PathwayEncoder.shared.encode(UnsupportedRoute(kind: kind))
        }
    }

}
