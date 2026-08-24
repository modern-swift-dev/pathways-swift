import Foundation
import Pathways
import Testing

@Suite(.serialized)
@MainActor struct PathwayRoutingCenterTests {

    @Test func pathURL() throws {
        let url = try #require(URL(string: "http://localhost/darth/vader"))

        var center = Pathways()
        center.register(host: "localhost", TestMultiFieldTypesPathway.self, handler: { _, _ in
            Issue.record("invalid handler invoked")
        })

        center.register(host: "localhost", TestSingleFieldPathway.self, handler: { _, _ in
            Issue.record("invalid handler invoked")
        })

        center.register(host: "localhost", path: "/darth/vader", handler: { _ in
            // nothing do
        })

        center.register(path: "/darth", handler: { _ in
            Issue.record("invalid handler invoked")
        })

        #expect(try center.handle(url) == true)
    }

    @Test func shortURL() throws {
        let url = try #require(URL(string: "http://localhost/user/1"))

        var center = Pathways()
        center.register(host: "localhost", TestMultiFieldTypesPathway.self, handler: { _, _ in
            Issue.record("invalid handler invoked")
        })

        center.register(host: "localhost", TestSingleFieldPathway.self, handler: { _, _ in
            // nothing to do
        })

        center.register(host: "localhost", path: "/darth/vader", handler: { _ in
            Issue.record("invalid handler invoked")
        })

        #expect(try center.handle(url) == true)
    }

    @Test func longURL() throws {
        let url = try #require(URL(string: "http://localhost/user/1/picture/2"))

        var center = Pathways()
        center.register(host: "localhost", TestMultiFieldTypesPathway.self, handler: { _, _ in
            // nothing to do
        })

        center.register(host: "localhost", TestSingleFieldPathway.self, handler: { _, _ in
            Issue.record("invalid handler invoked")
        })

        center.register(host: "localhost", path: "/darth/vader", handler: { _ in
            Issue.record("invalid handler invoked")
        })

        #expect(try center.handle(url) == true)
    }

    @Test func dummyURL() throws {
        let url = try #require(URL(string: "http://localhost/foo/1/bar/2"))

        var center = Pathways()
        center.register(host: "localhost", TestMultiFieldTypesPathway.self, handler: { _, _ in
            Issue.record("invalid handler invoked")
        })

        center.register(host: "localhost", TestSingleFieldPathway.self, handler: { _, _ in
            Issue.record("invalid handler invoked")
        })

        center.register(host: "localhost", path: "/darth/vader", handler: { _ in
            Issue.record("invalid handler invoked")
        })

        #expect(try center.handle(url) == false)
    }

    @Test func reset() throws {
        let url1 = try #require(URL(string: "http://localhost/user/1/picture/2"))

        var center = Pathways()
        center.register(host: "localhost", TestMultiFieldTypesPathway.self, handler: { _, _ in
            // nothing to do
        })

        #expect(try center.handle(url1) == true)
        center.reset()
        #expect(try center.handle(url1) == false)
    }

    @Test func prefixMatchingRemainsTheDefault() throws {
        let url = try #require(URL(string: "https://localhost/user/1/details"))
        var invoked = false

        var center = Pathways()
        center.register(host: "localhost", TestSingleFieldPathway.self) { _, _ in
            invoked = true
        }

        #expect(try center.handle(url))
        #expect(invoked)
    }

    @Test func exactPathRegistrationRejectsSimilarAndTrailingPaths() throws {
        let matchedURL = try #require(URL(string: "https://localhost/settings?tab=account"))
        let normalizedURL = try #require(URL(string: "https://localhost//settings"))
        let similarURL = try #require(URL(string: "https://localhost/settings-and-privacy"))
        let trailingURL = try #require(URL(string: "https://localhost/settings/privacy"))
        let otherHostURL = try #require(URL(string: "https://other.example/settings"))
        var receivedParameters: [String: String] = [:]

        var center = Pathways()
        center.register(host: "localhost", path: "/settings", matching: .exact) { parameters in
            receivedParameters = parameters
        }

        #expect(try center.handle(matchedURL))
        #expect(receivedParameters == ["tab": "account"])
        #expect(try center.handle(normalizedURL))
        #expect(try center.handle(similarURL) == false)
        #expect(try center.handle(trailingURL) == false)
        #expect(try center.handle(otherHostURL) == false)
    }

    @Test func exactTypedRegistrationMatchesOnePathComponent() throws {
        let matchedURL = try #require(URL(string: "https://localhost/user/1?campaign=summer"))
        let trailingURL = try #require(URL(string: "https://localhost/user/1/details"))
        var receivedRoute: TestSingleFieldPathway?
        var receivedParameters: [String: String] = [:]

        var center = Pathways()
        center.register(host: "localhost", TestSingleFieldPathway.self, matching: .exact) { route, parameters in
            receivedRoute = route
            receivedParameters = parameters
        }

        #expect(try center.handle(matchedURL))
        #expect(receivedRoute?.id == 1)
        #expect(receivedParameters == ["campaign": "summer"])
        #expect(try center.handle(trailingURL) == false)
    }

    @Test func exactTypedRegistrationReportsMalformedValues() throws {
        let url = try #require(URL(string: "https://localhost/user/not-a-number"))

        var center = Pathways()
        center.register(host: "localhost", TestSingleFieldPathway.self, matching: .exact) { _, _ in
            Issue.record("invalid handler invoked")
        }

        #expect(throws: (any Error).self) {
            try center.handle(url)
        }
    }

    @Test func exactPathRegistrationPreservesFragmentParameters() throws {
        let url = try #require(URL(string: "https://localhost/callback#complete?token=abc"))
        var receivedParameters: [String: String] = [:]

        var center = Pathways()
        center.register(
            host: "localhost",
            path: "/callback/#complete",
            matching: .exact,
            supportFragmentParams: true
        ) { parameters in
            receivedParameters = parameters
        }

        #expect(try center.handle(url))
        #expect(receivedParameters == ["token": "abc"])
    }
}
