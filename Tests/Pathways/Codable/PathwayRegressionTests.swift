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
        let url = try #require(URL(string: "https://localhost/callback#complete/123?token=abc"))
        #expect(try PathwayDecoder.shared.decode(FragmentRoute.self, from: url).id == "123")
        var router = Pathways()
        var received: String?
        router.register(host: "localhost", FragmentRoute.self, matching: matching, supportFragmentParams: true) { route, parameters in
            received = route.id
            #expect(parameters == ["token": "abc"])
        }
        #expect(try router.handle(url))
        #expect(received == "123")
    }

}
