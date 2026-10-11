import Foundation
import Pathways
import Testing

@MainActor struct PathwayProtocolTests {
    @Test func exactTypedRegistrationThroughProtocol() throws {
        var center: any PathwaysProviding = Pathways()
        center.baseHost = "localhost"
        var receivedID: Int?
        center.register(TestSingleFieldPathway.self, matching: .exact, supportFragmentParams: false) { route, _ in
            receivedID = route.id
        }

        #expect(try center.handle(#require(URL(string: "https://localhost/user/1"))))
        #expect(receivedID == 1)
        #expect(try center.handle(#require(URL(string: "https://localhost/user/1/details"))) == false)
    }

    @Test func exactHostTypedRegistrationThroughProtocol() throws {
        var center: any PathwaysProviding = Pathways()
        var receivedID: Int?
        center.register(host: "localhost", TestSingleFieldPathway.self, matching: .exact, supportFragmentParams: false) { route, _ in
            receivedID = route.id
        }

        #expect(try center.handle(#require(URL(string: "https://localhost/user/1"))))
        #expect(receivedID == 1)
        #expect(try center.handle(#require(URL(string: "https://localhost/user/1/details"))) == false)
        #expect(try center.handle(#require(URL(string: "https://other.example/user/1"))) == false)
    }

    @Test func exactPathRegistrationThroughProtocol() throws {
        var center: any PathwaysProviding = Pathways()
        center.baseHost = "localhost"
        var receivedParameters: [String: String] = [:]
        center.register(path: "/settings", matching: .exact, supportFragmentParams: false) { parameters in
            receivedParameters = parameters
        }

        #expect(try center.handle(#require(URL(string: "https://localhost/settings?tab=account"))))
        #expect(receivedParameters == ["tab": "account"])
        #expect(try center.handle(#require(URL(string: "https://localhost/settings/privacy"))) == false)
    }

    @Test func exactHostPathRegistrationThroughProtocol() throws {
        var center: any PathwaysProviding = Pathways()
        var receivedParameters: [String: String] = [:]
        center.register(host: "localhost", path: "/settings", matching: .exact, supportFragmentParams: false) { parameters in
            receivedParameters = parameters
        }

        #expect(try center.handle(#require(URL(string: "https://localhost/settings?tab=account"))))
        #expect(receivedParameters == ["tab": "account"])
        #expect(try center.handle(#require(URL(string: "https://localhost/settings/privacy"))) == false)
        #expect(try center.handle(#require(URL(string: "https://other.example/settings"))) == false)
    }

    @Test(arguments: [false, true]) func longerPatternWinsRegardlessOfRegistrationOrder(reverseOrder: Bool) throws {
        var center = Pathways()
        center.baseHost = "localhost"
        var selectedPattern: String?
        let patterns = reverseOrder ? ["/user/1", "/user"] : ["/user", "/user/1"]
        for pattern in patterns {
            center.register(path: pattern) { _ in selectedPattern = pattern }
        }
        center.register(path: "/zzz") { _ in Issue.record("Nonmatching handler invoked") }

        #expect(try center.handle(#require(URL(string: "https://localhost/user/1/details"))))
        #expect(selectedPattern == "/user/1")
    }

    private struct VersionRoute: Pathway {
        static let pattern = "/v/:id"
        let id: String
    }

    @Test(arguments: [false, true], ["2", ".well-known", "-", "z"])
    func literalComponentBeatsPlaceholder(reverseOrder: Bool, literal: String) throws {
        var center = Pathways()
        center.baseHost = "localhost"
        var selected: String?
        let registrations: [(inout Pathways) -> Void] = [
            { $0.register(path: "/v/\(literal)") { _ in selected = "literal" } },
            { $0.register(VersionRoute.self) { _, _ in selected = "typed" } }
        ]
        for register in reverseOrder ? registrations.reversed() : registrations {
            register(&center)
        }

        #expect(try center.handle(#require(URL(string: "https://localhost/v/\(literal)"))))
        #expect(selected == "literal")
        #expect(try center.handle(#require(URL(string: "https://localhost/v/other"))))
        #expect(selected == "typed")
    }

    @Test func longerLiteralPatternBeatsShorterTypedPattern() throws {
        var center = Pathways()
        center.baseHost = "localhost"
        var selected: String?
        center.register(TestSingleFieldPathway.self) { _, _ in selected = "typed" }
        center.register(path: "/user/1/details") { _ in selected = "literal" }

        #expect(try center.handle(#require(URL(string: "https://localhost/user/1/details"))))
        #expect(selected == "literal")
    }

    @Test func earlierLiteralBeatsLaterLiteral() throws {
        var center = Pathways()
        center.baseHost = "localhost"
        var selected: String?
        center.register(TestMultiFieldPathway.self) { _, _ in selected = "/user/:id/type/:type" }
        center.register(TestEnumPathway.self) { _, _ in selected = "/user/:user_id/type/:type" }
        center.register(path: "/user/1") { _ in selected = "/user/1" }

        #expect(try center.handle(#require(URL(string: "https://localhost/user/1/type/admin"))))
        #expect(selected == "/user/1")
    }

    @Test(arguments: [false, true]) func exactBeatsPrefixForEqualPatterns(reverseOrder: Bool) throws {
        var center = Pathways()
        center.baseHost = "localhost"
        var selected: PathwayMatchPolicy?
        for policy in reverseOrder ? [PathwayMatchPolicy.exact, .prefix] : [.prefix, .exact] {
            center.register(path: "/settings", matching: policy) { _ in selected = policy }
        }

        #expect(try center.handle(#require(URL(string: "https://localhost/settings"))))
        #expect(selected == .exact)
    }

    @Test(arguments: [false, true]) func hostSpecificBeatsHostlessForEqualPatterns(reverseOrder: Bool) throws {
        var center = Pathways()
        var selected: String?
        let registrations: [(inout Pathways) -> Void] = [
            { $0.register(path: "/settings") { _ in selected = "hostless" } },
            { $0.register(host: "localhost", path: "/settings") { _ in selected = "host" } }
        ]
        for register in reverseOrder ? registrations.reversed() : registrations {
            register(&center)
        }

        #expect(try center.handle(#require(URL(string: "https://localhost/settings"))))
        #expect(selected == "host")
    }

    @Test func equalPatternsSelectFirstRegisteredHandler() throws {
        var center = Pathways()
        center.baseHost = "localhost"
        var invocationOrder: [Int] = []
        center.register(path: "/settings") { _ in invocationOrder.append(1) }
        center.register(path: "/settings") { _ in invocationOrder.append(2) }

        #expect(try center.handle(#require(URL(string: "https://localhost/settings"))))
        #expect(invocationOrder == [1])
    }
}
