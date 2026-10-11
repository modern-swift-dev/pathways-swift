import Foundation
import Pathways
import Testing

struct PathwayErrorTests {
    private struct DateRoute: Pathway {
        static let pattern = "/date/:date"
        let date: Date
    }

    private struct IDRoute: Pathway {
        static let pattern = "/users/:id"
        let id: UUID
    }

    private struct NameRoute: Pathway {
        static let pattern = "/names/:name"
        let name: String
    }

    private struct NilRoute: PathwayEncodable {
        static let pattern = "/users/:id"

        enum CodingKeys: String, CodingKey {
            case id
        }

        func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encodeNil(forKey: .id)
        }
    }

    private struct UnfilledRoute: PathwayEncodable {
        static let pattern = "/teams/:team/members/:member"
        let team = "core"
    }

    private struct ExtraFieldRoute: PathwayEncodable {
        static let pattern = "/users/:id/:id"

        enum CodingKeys: String, CodingKey {
            case id
        }

        func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(1, forKey: .id)
            try container.encode(2, forKey: .id)
            try container.encode(3, forKey: .id)
        }
    }

    private struct MissingPlaceholderRoute: PathwayDecodable {
        static let pattern = "/users/:id"
        let id: String
        let name: String
    }

    @Test func decodeFailuresReportTheKeyAndRawComponent() throws {
        let url = try #require(URL(string: "https://localhost/user/abc"))
        #expect(throws: PathwayError.notDecodable(key: "id", value: "abc")) {
            try PathwayDecoder.shared.decode(TestSingleFieldPathway.self, from: url)
        }
    }

    @Test func malformedDateReportsTheKeyAndRawComponent() throws {
        let url = try #require(URL(string: "https://localhost/date/garbage"))
        #expect(throws: PathwayError.notDecodable(key: "date", value: "garbage")) {
            try PathwayDecoder.shared.decode(DateRoute.self, from: url)
        }
    }

    @Test func unknownEnumValueReportsTheKeyAndRawComponent() throws {
        let url = try #require(URL(string: "https://localhost/user/1/type/boss"))
        #expect(throws: PathwayError.notDecodable(key: "type", value: "boss")) {
            try PathwayDecoder.shared.decode(TestEnumPathway.self, from: url)
        }
    }

    @Test func malformedUUIDReportsTheKeyAndRawComponent() throws {
        let url = try #require(URL(string: "https://localhost/users/not-a-uuid"))
        #expect(throws: PathwayError.notDecodable(key: "id", value: "not-a-uuid")) {
            try PathwayDecoder.shared.decode(IDRoute.self, from: url)
        }
    }

    @Test func missingPlaceholderReportsTheKey() throws {
        let url = try #require(URL(string: "https://localhost/users/1"))
        #expect(throws: PathwayError.notFound(key: "name")) {
            try PathwayDecoder.shared.decode(MissingPlaceholderRoute.self, from: url)
        }
    }

    @Test func unfilledPlaceholderReportsTheKey() {
        #expect(throws: PathwayError.notEncodable(key: "member", value: nil)) {
            try PathwayEncoder.shared.encode(UnfilledRoute())
        }
    }

    @Test func emptyValueReportsTheKeyAndValue() {
        #expect(throws: PathwayError.notEncodable(key: "name", value: "")) {
            try PathwayEncoder.shared.encode(NameRoute(name: ""))
        }
    }

    @Test func explicitNilReportsTheKey() {
        #expect(throws: PathwayError.notEncodable(key: "id", value: nil)) {
            try PathwayEncoder.shared.encode(NilRoute())
        }
    }

    @Test func unmatchedKeyReportsTheKeyAndValue() {
        #expect(throws: PathwayError.notEncodable(key: "id", value: "3")) {
            try PathwayEncoder.shared.encode(ExtraFieldRoute())
        }
    }

    @Test func callersCanMatchTheKindWithoutInspectingDetails() throws {
        let url = try #require(URL(string: "https://localhost/user/abc"))
        let decodeError = #expect(throws: PathwayError.self) {
            try PathwayDecoder.shared.decode(TestSingleFieldPathway.self, from: url)
        }
        let encodeError = #expect(throws: PathwayError.self) {
            try PathwayEncoder.shared.encode(NameRoute(name: ""))
        }
        let missingError = #expect(throws: PathwayError.self) {
            try PathwayDecoder.shared.decode(MissingPlaceholderRoute.self, from: #require(URL(string: "https://localhost/users/1")))
        }

        switch decodeError {
            case .notDecodable:
                break
            default:
                Issue.record("Expected notDecodable, got \(String(describing: decodeError))")
        }
        guard case .notEncodable = encodeError else {
            Issue.record("Expected notEncodable, got \(String(describing: encodeError))")
            return
        }
        guard case .notFound = missingError else {
            Issue.record("Expected notFound, got \(String(describing: missingError))")
            return
        }
    }

    @Test(arguments: [
        (PathwayError.notDecodable(key: "id", value: "abc"), #"Cannot decode key "id" from "abc"."#),
        (.notDecodable(key: nil, value: nil), "The value cannot be decoded as a route."),
        (.notEncodable(key: "name", value: ""), #"Cannot encode "" for key "name"."#),
        (.notEncodable(key: "id", value: nil), #"Cannot encode a value for key "id"."#),
        (.notEncodable(key: nil, value: nil), "The value cannot be encoded as a route."),
        (.notFound(key: "name"), #"No value for key "name"."#),
        (.notFound(key: nil), "No value for the requested key."),
        (.invalidURL, "The URL path does not match the route pattern."),
        (.unsupported, "Pathways supports only flat Codable models; nested and unkeyed containers are unsupported.")
    ])
    func errorsDescribeThemselves(error: PathwayError, description: String) {
        #expect(error.description == description)
        #expect(description == "\(error)")
    }
}
