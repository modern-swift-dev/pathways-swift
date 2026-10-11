import Foundation
import Pathways
import Testing

@MainActor struct FallbackTests {
    @Test func fallbackReceivesUnmatchedURLs() throws {
        var router = PathwayRouter()
        router.baseHost = "localhost"
        var fallbackRequests: [PathwayRequest] = []
        router.fallback = { fallbackRequests.append($0) }
        router.register(path: "/settings") { _ in }
        let url = try #require(URL(string: "https://localhost/unknown?a=1&a=2"))

        #expect(try router.handle(url))
        #expect(fallbackRequests.map(\.url) == [url])
        #expect(fallbackRequests.first?.queryItems.map(\.value) == ["1", "2"])
    }

    @Test func fallbackRunsWhenEveryMatchDeclines() throws {
        var router: any PathwaysProviding = PathwayRouter()
        router.baseHost = "localhost"
        var visited: [String] = []
        router.fallback = { _ in visited.append("fallback") }
        router.register(path: "/settings") { _ in
            visited.append("declined")
            return .declined
        }

        #expect(try router.handle(#require(URL(string: "https://localhost/settings"))))
        #expect(visited == ["declined", "fallback"])
    }

    @Test func fallbackDoesNotRunWhenAHandlerHandlesTheURL() throws {
        var router = PathwayRouter()
        router.baseHost = "localhost"
        router.fallback = { _ in Issue.record("fallback ran for a handled URL") }
        router.register(path: "/settings") { _ in }

        #expect(try router.handle(#require(URL(string: "https://localhost/settings"))))
    }

    @Test(arguments: [
        "ftp://localhost/settings",
        "https://other.example/settings",
        "myapp:///settings"
    ])
    func fallbackDoesNotRunForRejectedURLs(_ address: String) throws {
        var router = PathwayRouter()
        router.baseHost = "localhost"
        router.allowedSchemes = ["https", "myapp"]
        router.fallback = { _ in Issue.record("fallback ran for a rejected URL") }

        #expect(try router.handle(#require(URL(string: address))) == false)
    }

    @Test func fallbackDoesNotRunAfterADecodeError() throws {
        var router = PathwayRouter()
        router.baseHost = "localhost"
        router.fallback = { _ in Issue.record("fallback ran after a decode error") }
        router.register(TestSingleFieldPathway.self) { _, _ in }

        #expect(throws: PathwayError.self) {
            try router.handle(#require(URL(string: "https://localhost/user/abc")))
        }
    }

    @Test func withoutAFallbackUnmatchedURLsReturnFalse() throws {
        var router = PathwayRouter()
        router.baseHost = "localhost"
        #expect(router.fallback == nil)
        #expect(try router.handle(#require(URL(string: "https://localhost/unknown"))) == false)

        router.fallback = { _ in }
        #expect(try router.handle(#require(URL(string: "https://localhost/unknown"))))
        router.fallback = nil
        #expect(try router.handle(#require(URL(string: "https://localhost/unknown"))) == false)
    }

    @Test func resetKeepsTheFallback() throws {
        var router = PathwayRouter()
        router.baseHost = "localhost"
        var fallbackCount = 0
        router.fallback = { _ in fallbackCount += 1 }
        router.register(path: "/settings") { _ in }

        router.reset()

        #expect(try router.handle(#require(URL(string: "https://localhost/settings"))))
        #expect(fallbackCount == 1)
    }
}
