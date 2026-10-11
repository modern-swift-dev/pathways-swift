import Foundation
import Pathways
import Testing

@MainActor struct DeclineTests {
    private struct VersionRoute: Pathway {
        static let pattern = "/v/:id"
        let id: Int
    }

    @Test func declinedURLFallsThroughInPrecedenceOrder() throws {
        var router = PathwayRouter()
        router.baseHost = "localhost"
        var visited: [String] = []
        router.register(path: "/v") { _ in
            visited.append("prefix")
            return .handled
        }
        router.register(VersionRoute.self) { _, _ in
            visited.append("typed")
            return .declined
        }
        router.register(path: "/v/1") { _ in
            visited.append("literal")
            return .declined
        }
        router.register(host: "localhost", path: "/v/1") { _ in
            visited.append("host literal")
            return .declined
        }

        #expect(try router.handle(#require(URL(string: "https://localhost/v/1"))))
        #expect(visited == ["host literal", "literal", "typed", "prefix"])
    }

    @Test func equallySpecificRegistrationsFallThroughInRegistrationOrder() throws {
        var router = PathwayRouter()
        router.baseHost = "localhost"
        var visited: [Int] = []
        for index in 1 ... 3 {
            router.register(path: "/settings") { _ in
                visited.append(index)
                return index == 3 ? .handled : .declined
            }
        }

        #expect(try router.handle(#require(URL(string: "https://localhost/settings"))))
        #expect(visited == [1, 2, 3])
    }

    @Test func handleReturnsFalseWhenEveryMatchDeclines() throws {
        var router: any PathwaysProviding = PathwayRouter()
        router.baseHost = "localhost"
        var visited = 0
        router.register(TestSingleFieldPathway.self) { _, _ in
            visited += 1
            return .declined
        }
        router.register(host: "localhost", path: "/user") { _ in
            visited += 1
            return .declined
        }

        #expect(try router.handle(#require(URL(string: "https://localhost/user/1"))) == false)
        #expect(visited == 2)
    }

    @Test func dictionaryHandlersCountAsHandled() throws {
        var router = PathwayRouter()
        router.baseHost = "localhost"
        var visited: [String] = []
        router.register(path: "/a") { _ in visited.append("less specific") }
        router.register(path: "/a/b") { parameters in visited.append("dictionary \(parameters)") }
        router.register(TestSingleFieldPathway.self) { route, _ in visited.append("typed \(route.id)") }

        #expect(try router.handle(#require(URL(string: "https://localhost/a/b?x=1"))))
        #expect(try router.handle(#require(URL(string: "https://localhost/user/1"))))
        #expect(visited == ["dictionary [\"x\": \"1\"]", "typed 1"])
    }

    @Test func decodeErrorsStillThrowAfterADecline() throws {
        var router = PathwayRouter()
        router.baseHost = "localhost"
        router.register(path: "/v/abc") { _ in .declined }
        router.register(VersionRoute.self) { _, _ in
            Issue.record("handler invoked for an undecodable route")
            return .handled
        }
        router.register(path: "/v") { _ in Issue.record("decode error fell through") }

        #expect(throws: PathwayError.notDecodable(key: "id", value: "abc")) {
            try router.handle(#require(URL(string: "https://localhost/v/abc")))
        }
    }

    @Test func resultHandlersRegisterThroughEverySpelling() throws {
        var router: any PathwaysProviding = PathwayRouter()
        router.baseHost = "localhost"
        var visited: [String] = []
        router.register(host: "localhost", TestSingleFieldPathway.self, matching: .exact) { _, _ in
            visited.append("host typed")
            return .declined
        }
        router.register(TestSingleFieldPathway.self, supportFragmentParams: true) { _, _ in
            visited.append("typed")
            return .declined
        }
        router.register(host: "localhost", path: "/user", matching: .exact) { _ in
            visited.append("host path")
            return .declined
        }
        router.register(path: "/user") { _ in
            visited.append("path")
            return .declined
        }

        #expect(try router.handle(#require(URL(string: "https://localhost/user/1"))) == false)
        #expect(visited == ["host typed", "typed", "path"])
        visited.removeAll()
        #expect(try router.handle(#require(URL(string: "https://localhost/user"))) == false)
        #expect(visited == ["host path", "path"])
    }
}
