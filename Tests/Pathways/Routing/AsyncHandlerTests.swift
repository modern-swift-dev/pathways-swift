import Foundation
import Pathways
import Testing

@MainActor struct AsyncHandlerTests {
    private func load(_ value: Int) async -> Int {
        await Task.yield()
        return value
    }

    @Test func asyncHandleAwaitsAsyncTypedAndPathHandlers() async throws {
        var router = PathwayRouter()
        router.baseHost = "localhost"
        var loaded: [Int] = []
        router.register(TestSingleFieldPathway.self) { route, _ in
            await loaded.append(self.load(route.id))
            return .handled
        }
        router.register(host: "localhost", path: "/settings") { request in
            await loaded.append(self.load(request.queryItems.count))
            return .handled
        }

        #expect(try await router.handle(#require(URL(string: "https://localhost/user/7"))))
        #expect(try await router.handle(#require(URL(string: "https://localhost/settings?a&b"))))
        #expect(loaded == [7, 2])
    }

    @Test func asyncHandleRunsSyncHandlersAndHonoursPrecedenceAndFallThrough() async throws {
        var router = PathwayRouter()
        router.baseHost = "localhost"
        var visited: [String] = []
        router.register(path: "/v") { _ in visited.append("sync dictionary") }
        router.register(path: "/v/1") { _ in
            await Task.yield()
            visited.append("async declined")
            return .declined
        }
        router.register(host: "localhost", path: "/v/1") { _ in
            visited.append("sync declined")
            return .declined
        }

        #expect(try await router.handle(#require(URL(string: "https://localhost/v/1"))))
        #expect(visited == ["sync declined", "async declined", "sync dictionary"])
    }

    @Test func asyncHandleRunsTheFallbackWhenEveryMatchDeclines() async throws {
        var router: any PathwaysProviding = PathwayRouter()
        router.baseHost = "localhost"
        var visited: [String] = []
        router.fallback = { _ in visited.append("fallback") }
        router.register(TestSingleFieldPathway.self) { _, _ in
            await Task.yield()
            visited.append("async")
            return .declined
        }

        #expect(try await router.handle(#require(URL(string: "https://localhost/user/1"))))
        #expect(try await router.handle(#require(URL(string: "https://localhost/unknown"))))
        #expect(visited == ["async", "fallback", "fallback"])
    }

    @Test func asyncHandleRejectsLikeTheSynchronousHandle() async throws {
        var router = PathwayRouter()
        router.baseHost = "localhost"
        router.allowedSchemes = ["https"]
        router.fallback = { _ in Issue.record("fallback ran for a rejected URL") }
        router.register(TestSingleFieldPathway.self) { _, _ in
            Issue.record("handler invoked for an undecodable route")
            return .handled
        }

        #expect(try await router.handle(#require(URL(string: "http://localhost/user/1"))) == false)
        #expect(try await router.handle(#require(URL(string: "https://other.example/user/1"))) == false)
        await #expect(throws: PathwayError.notDecodable(key: "id", value: "abc")) {
            try await router.handle(#require(URL(string: "https://localhost/user/abc")))
        }
    }

    @Test func synchronousHandleThrowsWhenTheSelectedHandlerIsAsync() throws {
        var router = PathwayRouter()
        router.baseHost = "localhost"
        router.fallback = { _ in Issue.record("fallback ran instead of throwing") }
        router.register(path: "/a") { _ in Issue.record("less specific handler ran instead of throwing") }
        router.register(path: "/a/b") { _ in
            await Task.yield()
            return .handled
        }

        #expect(throws: PathwayRouterError.asyncHandlerRequiresAsyncHandle) {
            try router.handle(#require(URL(string: "https://localhost/a/b")))
        }
    }

    @Test func synchronousHandleThrowsWhenFallThroughReachesAnAsyncHandler() throws {
        var router: any PathwaysProviding = PathwayRouter()
        router.baseHost = "localhost"
        var visited: [String] = []
        router.register(host: "localhost", TestSingleFieldPathway.self, matching: .exact) { _, _ in
            visited.append("sync declined")
            return .declined
        }
        router.register(TestSingleFieldPathway.self) { _, _ in
            await Task.yield()
            Issue.record("async handler ran from the synchronous handle")
            return .handled
        }

        #expect(throws: PathwayRouterError.asyncHandlerRequiresAsyncHandle) {
            try router.handle(#require(URL(string: "https://localhost/user/1")))
        }
        #expect(visited == ["sync declined"])
    }

    @Test func synchronousHandleIgnoresAsyncHandlersThatDoNotMatch() throws {
        var router = PathwayRouter()
        router.baseHost = "localhost"
        var handled = false
        router.register(path: "/async") { _ in
            await Task.yield()
            return .handled
        }
        router.register(path: "/sync") { _ in handled = true }

        #expect(try router.handle(#require(URL(string: "https://localhost/sync"))))
        #expect(handled)
    }

    @Test func asyncHandlersRegisterThroughEverySpelling() async throws {
        var router: any PathwaysProviding = PathwayRouter()
        router.baseHost = "localhost"
        var visited: [String] = []
        router.register(host: "localhost", TestSingleFieldPathway.self, matching: .exact) { _, _ in
            await Task.yield()
            visited.append("host typed")
            return .declined
        }
        router.register(TestSingleFieldPathway.self, supportFragmentParams: true) { _, _ in
            await Task.yield()
            visited.append("typed")
            return .declined
        }
        router.register(host: "localhost", path: "/user", matching: .exact) { _ in
            await Task.yield()
            visited.append("host path")
            return .declined
        }
        router.register(path: "/user") { _ in
            await Task.yield()
            visited.append("path")
            return .declined
        }

        #expect(try await router.handle(#require(URL(string: "https://localhost/user/1"))) == false)
        #expect(try await router.handle(#require(URL(string: "https://localhost/user"))) == false)
        #expect(visited == ["host typed", "typed", "path", "host path", "path"])
    }

    @Test func asyncHandlerRequiresAsyncHandleDescribesItself() {
        #expect(PathwayRouterError.asyncHandlerRequiresAsyncHandle.description
            == "The selected handler is asynchronous; call the async handle(_:) instead.")
    }
}
