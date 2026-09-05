import Foundation
import Pathways
import Testing

@MainActor struct PreparedHandlerTests {
    private struct DynamicRoute: Pathway {
        @TaskLocal static var currentPattern = "/first/:id"
        static var pattern: String {
            currentPattern
        }

        let id: String
    }

    @Test func computedPatternsStillReflectChangesAfterRegistration() throws {
        var router = Pathways()
        router.baseHost = "localhost"
        router.register(DynamicRoute.self, matching: .exact) { route, _ in
            #expect(route.id == "value")
        }
        let first = try #require(URL(string: "https://localhost/first/value"))
        let second = try #require(URL(string: "https://localhost/second/value"))
        #expect(try router.handle(first))
        #expect(try router.handle(second) == false)
        try DynamicRoute.$currentPattern.withValue("/second/:id") { () throws in
            #expect(try router.handle(second))
            #expect(try router.handle(first) == false)
            #expect(router.registeredPatterns() == ["/second/:id"])
        }
        #expect(try router.handle(first))
    }

    @Test(arguments: [PathwayMatchPolicy.prefix, .exact]) func preparedLiteralPathsPreserveEscaping(_ policy: PathwayMatchPolicy) throws {
        var router = Pathways()
        router.baseHost = "localhost"
        router.register(path: "/café/hello world", matching: policy) { _ in }
        let url = try #require(URL(string: "https://localhost/caf%C3%A9/hello%20world"))
        #expect(try router.handle(url))
        #expect(try router.handle(url))
        #expect(router.registeredPatterns() == ["/café/hello world"])
    }
}
