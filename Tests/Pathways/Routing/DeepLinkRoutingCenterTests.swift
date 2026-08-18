import Foundation
import Pathways
import Testing

// swiftlint:disable force_unwrapping
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
}
