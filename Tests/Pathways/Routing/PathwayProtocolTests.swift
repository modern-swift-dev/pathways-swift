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

    @Test(arguments: [false, true]) func lexicalPrecedenceIgnoresRegistrationOrder(reverseOrder: Bool) throws {
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

    @Test func lexicalPrecedenceDoesNotPreferLongerLiteralPattern() throws {
        var center = Pathways()
        center.baseHost = "localhost"
        var receivedID: Int?
        center.register(path: "/user/1/details") { _ in
            Issue.record("Longer but lexically smaller pattern selected")
        }
        center.register(TestSingleFieldPathway.self) { route, _ in receivedID = route.id }

        #expect(try center.handle(#require(URL(string: "https://localhost/user/1/details"))))
        #expect(receivedID == 1)
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
