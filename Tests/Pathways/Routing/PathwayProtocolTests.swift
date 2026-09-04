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
}
