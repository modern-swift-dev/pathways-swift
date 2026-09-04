import Foundation
import Pathways
import Testing

struct PathwayRegressionTests {

    private struct DateRoute: Pathway {
        static let pattern = "/date/:date"
        let date: Date
    }

    @Test func invalidDateThrowsAndValidDateDecodes() throws {
        let invalid = try #require(URL(string: "https://localhost/date/garbage"))
        #expect(throws: PathwayError.notDecodable) {
            try PathwayDecoder.shared.decode(DateRoute.self, from: invalid)
        }
        let valid = try #require(URL(string: "https://localhost/date/2026-09-04T12:00:00Z"))
        let date = try PathwayDecoder.shared.decode(DateRoute.self, from: valid).date
        #expect(date.timeIntervalSince1970 == 1_788_523_200)
    }

    private struct StringRoute: Pathway {
        static let pattern = "/user/:id"
        let id: String
    }

    @Test(arguments: ["?", "??", "?token=abc"])
    @MainActor func emptyFragmentRoutesDoNotCrash(_ fragment: String) throws {
        let url = try #require(URL(string: "https://localhost/user/123#" + fragment))
        #expect(try PathwayDecoder.shared.decode(StringRoute.self, from: url).id == "123")

        var typed = Pathways()
        typed.register(host: "localhost", StringRoute.self, matching: .exact) { route, _ in
            #expect(route.id == "123")
        }
        #expect(try typed.handle(url))

        var path = Pathways()
        path.register(host: "localhost", path: "/user/123", matching: .exact) { _ in }
        #expect(try path.handle(url))
    }

    private struct LiteralRoute: Pathway {
        static let pattern = "/file[/:id"
        let id: String
    }

    private struct DotRoute: Pathway {
        static let pattern = "/v1.0/:id"
        let id: String
    }

    @Test(arguments: [PathwayMatchPolicy.prefix, .exact])
    @MainActor func regexMetacharactersAreLiteral(_ matching: PathwayMatchPolicy) throws {
        let bracket = try #require(URL(string: "https://localhost/file%5B/123"))
        #expect(try PathwayDecoder.shared.decode(LiteralRoute.self, from: bracket).id == "123")
        var router = Pathways()
        router.register(host: "localhost", LiteralRoute.self, matching: matching) { route, _ in
            #expect(route.id == "123")
        }
        #expect(try router.handle(bracket))

        router.register(host: "localhost", DotRoute.self, matching: matching) { _, _ in }
        let dot = try #require(URL(string: "https://localhost/v1.0/123"))
        let impostor = try #require(URL(string: "https://localhost/v1X0/123"))
        #expect(try router.handle(dot))
        #expect(try router.handle(impostor) == false)
        #expect(throws: PathwayError.invalidURL) {
            try PathwayDecoder.shared.decode(DotRoute.self, from: impostor)
        }
    }

    private struct FragmentRoute: Pathway {
        static let pattern = "/callback/#complete/:id"
        let id: String
    }

    @Test(arguments: ["/user//type/a", "/user/1/type/", "/user/1/type"]) func missingComponentsThrow(_ path: String) throws {
        let url = try #require(URL(string: "https://localhost" + path))
        #expect(throws: (any Error).self) {
            try PathwayDecoder.shared.decode(TestMultiFieldPathway.self, from: url)
        }
    }

    @Test(arguments: [PathwayMatchPolicy.prefix, .exact])
    @MainActor func typedFragmentPreservesValuesAndParameters(_ matching: PathwayMatchPolicy) throws {
        let url = try #require(URL(string: "https://localhost/callback#complete/a%2Fb%3Fc%23d?token=x%26y%3Dz"))
        #expect(try PathwayDecoder.shared.decode(FragmentRoute.self, from: url).id == "a/b?c#d")
        var router = Pathways()
        var received: String?
        router.register(host: "localhost", FragmentRoute.self, matching: matching, supportFragmentParams: true) { route, parameters in
            received = route.id
            #expect(parameters == ["token": "x&y=z"])
        }
        #expect(try router.handle(url))
        #expect(received == "a/b?c#d")
    }

    @Test(arguments: ["a/b", "a?b", "a#b", "a%20b", "hello world", "é/你好", "a&b=c"])
    @MainActor func stringRoundTripsPreserveComponentBoundaries(_ value: String) throws {
        let base = try #require(URL(string: "https://localhost"))
        let url = try #require(try PathwayEncoder.shared.encode(StringRoute(id: value), relativeTo: base))
        #expect(try PathwayDecoder.shared.decode(StringRoute.self, from: url).id == value)

        var received: String?
        var router = Pathways()
        router.register(host: "localhost", StringRoute.self, matching: .exact) { route, _ in
            received = route.id
        }
        #expect(try router.handle(url))
        #expect(received == value)
    }

    @Test func slashIsEncodedInsideAPlaceholder() throws {
        #expect(try PathwayEncoder.shared.encode(StringRoute(id: "a/b")) == "/user/a%2Fb")
    }

    private struct CodingPathValue: Decodable, Sendable {
        let path: [String]
        let value: String

        init(from decoder: any Decoder) throws {
            path = decoder.codingPath.map(\.stringValue)
            value = try decoder.singleValueContainer().decode(String.self)
        }
    }

    private struct InspectedRoute: PathwayDecodable {
        static let pattern = "/user/:identifier/:second"
        let first: CodingPathValue
        let second: CodingPathValue

        enum CodingKeys: String, CodingKey {
            case id
            case identifier
            case second
            case absent
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            #expect(Set(container.allKeys.map(\.stringValue)) == ["identifier", "second"])
            #expect(container.contains(.identifier))
            #expect(container.contains(.id) == false)
            #expect(container.contains(.absent) == false)
            #expect(try container.decodeIfPresent(String.self, forKey: .absent) == nil)
            #expect(throws: PathwayError.notDecodable) {
                try container.decode(Int.self, forKey: .identifier)
            }
            #expect(container.codingPath.isEmpty)
            first = try container.decode(CodingPathValue.self, forKey: .identifier)
            second = try container.decode(CodingPathValue.self, forKey: .second)
            #expect(try container.decodeIfPresent(String.self, forKey: .identifier) == "first")
            #expect(container.codingPath.isEmpty)
            #expect(decoder.codingPath.isEmpty)
        }
    }

    @Test func keyedDecoderReportsKeysAndRestoresCodingPaths() throws {
        let url = try #require(URL(string: "https://localhost/user/first/second"))
        let route = try PathwayDecoder.shared.decode(InspectedRoute.self, from: url)
        #expect(route.first.path == ["identifier"])
        #expect(route.first.value == "first")
        #expect(route.second.path == ["second"])
        #expect(route.second.value == "second")
    }
}
