import Foundation
import Pathways
import Testing

@MainActor struct UnregisterTests {
    @Test func unregisteringRemovesOnlyThatRegistration() throws {
        var router = PathwayRouter()
        router.baseHost = "localhost"
        var selected: [String] = []
        let first = router.register(path: "/settings") { _ in selected.append("first") }
        router.register(path: "/settings") { _ in selected.append("second") }
        let typed = router.register(TestSingleFieldPathway.self) { _, _ in selected.append("typed") }

        router.unregister(first)
        router.unregister(typed)

        #expect(try router.handle(#require(URL(string: "https://localhost/settings"))))
        #expect(try router.handle(#require(URL(string: "https://localhost/user/1"))) == false)
        #expect(selected == ["second"])
        #expect(router.registeredPatterns() == ["/settings"])
    }

    @Test func unregisteringAHostSpecificRegistrationForgetsItsHost() throws {
        var router = PathwayRouter()
        let registration = router.register(host: "example.com", path: "/a") { _ in }
        router.register(path: "/a") { _ in Issue.record("hostless handler admitted by a removed host") }

        router.unregister(registration)

        #expect(router.registeredHosts().isEmpty)
        #expect(try router.handle(#require(URL(string: "https://example.com/a"))) == false)
    }

    @Test func unknownOrRemovedIdentifiersAreIgnored() throws {
        var router = PathwayRouter()
        router.baseHost = "localhost"
        var other = PathwayRouter()
        let foreign = other.register(path: "/a") { _ in }
        let registration = router.register(path: "/a") { _ in }

        router.unregister(foreign)
        #expect(try router.handle(#require(URL(string: "https://localhost/a"))))

        router.unregister(registration)
        router.unregister(registration)
        #expect(try router.handle(#require(URL(string: "https://localhost/a"))) == false)
        #expect(other.registeredPatterns() == ["/a"])
    }

    @Test func copiesUnregisterIndependently() throws {
        var router = PathwayRouter()
        router.baseHost = "localhost"
        let registration = router.register(path: "/a") { _ in }
        var copy = router
        let url = try #require(URL(string: "https://localhost/a"))

        copy.unregister(registration)

        #expect(try router.handle(url))
        #expect(try copy.handle(url) == false)

        let next = copy.register(path: "/b") { _ in }
        router.register(path: "/b") { _ in }
        router.unregister(next)
        #expect(try router.handle(#require(URL(string: "https://localhost/b"))))
    }

    @Test func registrationsAreUniqueAndUnregisterThroughTheProtocol() throws {
        var router: any PathwaysProviding = PathwayRouter()
        router.baseHost = "localhost"
        let ids = [
            router.register(TestSingleFieldPathway.self) { _, _ in },
            router.register(host: "localhost", TestSingleFieldPathway.self) { _, _ in },
            router.register(path: "/a") { _ in },
            router.register(host: "localhost", path: "/a") { _ in }
        ]
        #expect(Set(ids).count == ids.count)

        for id in ids {
            router.unregister(id)
        }

        #expect(router.registeredPatterns().isEmpty)
        #expect(try router.handle(#require(URL(string: "https://localhost/user/1"))) == false)
    }
}
