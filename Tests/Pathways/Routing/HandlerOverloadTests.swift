import Foundation
import Pathways
import Testing

/// Handler closures must resolve to one registration form without
/// annotations: dictionary handlers whenever the body allows it, and the
/// declinable request form only when the body returns a result.
@MainActor struct HandlerOverloadTests {
    @Test func multiStatementClosuresIgnoringTheirArgumentsAreDictionaryHandlers() throws {
        var router = PathwayRouter()
        router.baseHost = "localhost"
        var log: [String] = []
        router.register(path: "/path") { _ in
            log.append("path")
            log.append("done")
        }
        router.register(TestSingleFieldPathway.self) { _, _ in
            log.append("typed")
            log.append("done")
        }

        #expect(try router.handle(#require(URL(string: "https://localhost/path"))))
        #expect(try router.handle(#require(URL(string: "https://localhost/user/1"))))
        #expect(log == ["path", "done", "typed", "done"])
    }

    @Test func parametersUsedOnlyThroughInterpolationStayADictionary() throws {
        var router = PathwayRouter()
        router.baseHost = "localhost"
        var log: [String] = []
        router.register(path: "/path") { parameters in log.append("\(parameters)") }
        router.register(TestSingleFieldPathway.self) { _, parameters in
            log.append("typed")
            log.append("\(parameters)")
        }

        #expect(try router.handle(#require(URL(string: "https://localhost/path?a=1"))))
        #expect(try router.handle(#require(URL(string: "https://localhost/user/1?b=2"))))
        #expect(log == [#"["a": "1"]"#, "typed", #"["b": "2"]"#])
    }

    @Test func closuresReturningAResultAreDeclinable() throws {
        var router = PathwayRouter()
        router.baseHost = "localhost"
        var log: [String] = []
        router.register(path: "/path") { _ in .declined }
        router.register(path: "/path") { _ in
            log.append("declined")
            return .declined
        }
        router.register(path: "/path") { _ in log.append("handled") }
        router.register(TestSingleFieldPathway.self) { route, request in
            guard route.id == 1, request.queryItems.isEmpty else {
                return .declined
            }
            log.append("typed")
            return .handled
        }

        #expect(try router.handle(#require(URL(string: "https://localhost/path"))))
        #expect(try router.handle(#require(URL(string: "https://localhost/user/1"))))
        #expect(try router.handle(#require(URL(string: "https://localhost/user/1?a"))) == false)
        #expect(log == ["declined", "handled", "typed"])
    }
}
