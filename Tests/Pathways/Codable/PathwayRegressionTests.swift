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

}
