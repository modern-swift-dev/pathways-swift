import Foundation
import Pathways
import Testing

/// Every registration spelling must compile, unambiguously, on the concrete
/// router and through the routing protocol, and route the URL it describes.
@MainActor struct RegistrationSpellingTests {
    private static let typedURLs = [
        "https://host.example/user/1",
        "https://host.example/user/2",
        "https://host.example/user/3",
        "https://host.example/user/4",
        "https://localhost/user/5",
        "https://localhost/user/6",
        "https://localhost/user/7",
        "https://localhost/user/8"
    ]

    private static let pathURLs = [
        "https://host.example/a",
        "https://host.example/b",
        "https://host.example/c",
        "https://host.example/d",
        "https://localhost/e",
        "https://localhost/f",
        "https://localhost/g",
        "https://localhost/h"
    ]

    @Test func everySpellingRoutesOnTheConcreteRouter() throws {
        var router = PathwayRouter()
        router.baseHost = "localhost"
        var typed: [Int] = []
        var paths: [String] = []

        router.register(host: "host.example", TestSingleFieldPathway.self) { route, _ in typed.append(route.id) }
        router.register(host: "host.example", TestSingleFieldPathway.self, matching: .exact) { route, _ in typed.append(route.id) }
        router.register(host: "host.example", TestSingleFieldPathway.self, supportFragmentParams: true) { route, _ in typed.append(route.id) }
        router.register(host: "host.example", TestSingleFieldPathway.self, matching: .exact, supportFragmentParams: true) { route, _ in typed.append(route.id) }
        router.register(TestSingleFieldPathway.self) { route, _ in typed.append(route.id) }
        router.register(TestSingleFieldPathway.self, matching: .exact) { route, _ in typed.append(route.id) }
        router.register(TestSingleFieldPathway.self, supportFragmentParams: true) { route, _ in typed.append(route.id) }
        router.register(TestSingleFieldPathway.self, matching: .exact, supportFragmentParams: true) { route, _ in typed.append(route.id) }

        router.register(host: "host.example", path: "/a") { _ in paths.append("a") }
        router.register(host: "host.example", path: "/b", matching: .exact) { _ in paths.append("b") }
        router.register(host: "host.example", path: "/c", supportFragmentParams: true) { _ in paths.append("c") }
        router.register(host: "host.example", path: "/d", matching: .exact, supportFragmentParams: true) { _ in paths.append("d") }
        router.register(path: "/e") { _ in paths.append("e") }
        router.register(path: "/f", matching: .exact) { _ in paths.append("f") }
        router.register(path: "/g", supportFragmentParams: true) { _ in paths.append("g") }
        router.register(path: "/h", matching: .exact, supportFragmentParams: true) { _ in paths.append("h") }

        for address in Self.typedURLs + Self.pathURLs {
            #expect(try router.handle(#require(URL(string: address))))
        }
        #expect(typed.count == 8)
        #expect(paths == ["a", "b", "c", "d", "e", "f", "g", "h"])
        #expect(router.registeredPatterns().count == 16)
    }

    @Test func everySpellingRoutesThroughTheProtocol() throws {
        var router: any PathwaysProviding = PathwayRouter()
        router.baseHost = "localhost"
        var paths: [String] = []

        router.register(host: "host.example", TestSingleFieldPathway.self) { _, _ in }
        router.register(host: "host.example", TestSingleFieldPathway.self, matching: .exact) { _, _ in }
        router.register(host: "host.example", TestSingleFieldPathway.self, supportFragmentParams: true) { _, _ in }
        router.register(host: "host.example", TestSingleFieldPathway.self, matching: .exact, supportFragmentParams: true) { _, _ in }
        router.register(TestSingleFieldPathway.self) { _, _ in }
        router.register(TestSingleFieldPathway.self, matching: .exact) { _, _ in }
        router.register(TestSingleFieldPathway.self, supportFragmentParams: true) { _, _ in }
        router.register(TestSingleFieldPathway.self, matching: .exact, supportFragmentParams: true) { _, _ in }

        router.register(host: "host.example", path: "/a") { _ in paths.append("a") }
        router.register(host: "host.example", path: "/b", matching: .exact) { _ in paths.append("b") }
        router.register(host: "host.example", path: "/c", supportFragmentParams: true) { _ in paths.append("c") }
        router.register(host: "host.example", path: "/d", matching: .exact, supportFragmentParams: true) { _ in paths.append("d") }
        router.register(path: "/e") { _ in paths.append("e") }
        router.register(path: "/f", matching: .exact) { _ in paths.append("f") }
        router.register(path: "/g", supportFragmentParams: true) { _ in paths.append("g") }
        router.register(path: "/h", matching: .exact, supportFragmentParams: true) { _ in paths.append("h") }

        for address in Self.typedURLs + Self.pathURLs {
            #expect(try router.handle(#require(URL(string: address))))
        }
        #expect(paths == ["a", "b", "c", "d", "e", "f", "g", "h"])
        #expect(router.registeredPatterns().count == 16)
    }

    @Test func optionalHostSelectsHostSpecificOrHostlessRegistration() throws {
        var router = PathwayRouter()
        router.baseHost = "localhost"
        let hosts: [String?] = ["host.example", nil]
        var selected: [String] = []
        for host in hosts {
            router.register(host: host, path: "/settings", matching: .exact, supportFragmentParams: false) { _ in
                selected.append(host ?? "hostless")
            }
        }

        #expect(router.registeredHosts() == ["host.example"])
        #expect(try router.handle(#require(URL(string: "https://host.example/settings"))))
        #expect(try router.handle(#require(URL(string: "https://localhost/settings"))))
        #expect(selected == ["host.example", "hostless"])
    }

    @Test func fragmentParametersFollowTheRegistrationFlag() throws {
        var router: any PathwaysProviding = PathwayRouter()
        var received: [[String: String]] = []
        router.register(host: "localhost", path: "/on", supportFragmentParams: true) { received.append($0) }
        router.register(host: "localhost", path: "/off") { received.append($0) }

        #expect(try router.handle(#require(URL(string: "https://localhost/on#x?token=a"))))
        #expect(try router.handle(#require(URL(string: "https://localhost/off#x?token=a"))))
        #expect(received == [["token": "a"], [:]])
    }
}
