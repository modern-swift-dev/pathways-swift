import Foundation
import Pathways
import Testing

@MainActor struct HostAdmissionTests {
    @Test func hostlessRegistrationAcceptsDeclaredHostsAndCurrentBaseHost() throws {
        var router = PathwayRouter()
        router.register(host: "declared.example", path: "/other") { _ in }
        router.register(host: "declared.example", path: "/duplicate") { _ in }
        router.register(path: "/target") { _ in }
        let declared = try #require(URL(string: "https://declared.example/target"))
        let base = try #require(URL(string: "https://base.example/target"))
        #expect(try router.handle(declared))
        #expect(try router.handle(base) == false)
        router.baseHost = "base.example"
        #expect(try router.handle(base))
        #expect(router.registeredHosts() == ["declared.example", "declared.example"])

        var copy = router
        router.reset()
        router.register(path: "/target") { _ in }
        #expect(try router.handle(declared) == false)
        #expect(try router.handle(base))
        #expect(try copy.handle(declared))
        copy.baseHost = "new.example"
        #expect(try copy.handle(base) == false)
        #expect(try router.handle(base))
    }
}

@MainActor struct HostCaseTests {
    @Test(arguments: ["https://example.com/a", "https://EXAMPLE.com/a", "https://Example.Com/a"])
    func registeredHostsMatchCaseInsensitively(_ address: String) throws {
        var router = PathwayRouter()
        router.register(host: "Example.COM", path: "/a") { _ in }
        #expect(try router.handle(#require(URL(string: address))))
        #expect(router.registeredHosts() == ["example.com"])
    }

    @Test func baseHostMatchesCaseInsensitively() throws {
        var router = PathwayRouter()
        router.baseHost = "Base.Example"
        router.register(path: "/target") { _ in }
        #expect(try router.handle(#require(URL(string: "https://base.EXAMPLE/target"))))
    }
}

@MainActor struct SchemeAdmissionTests {
    @Test func anySchemeIsAcceptedByDefault() throws {
        var router = PathwayRouter()
        router.register(host: "example.com", path: "/a") { _ in }
        #expect(router.allowedSchemes == nil)
        #expect(try router.handle(#require(URL(string: "ftp://example.com/a"))))
    }

    @Test(arguments: [
        ("https://example.com/a", true),
        ("HTTPS://example.com/a", true),
        ("http://example.com/a", false),
        ("ftp://example.com/a", false)
    ])
    func allowedSchemesRestrictRouting(address: String, expected: Bool) throws {
        var router = PathwayRouter()
        router.allowedSchemes = ["HTTPS"]
        router.register(host: "example.com", path: "/a") { _ in }
        #expect(try router.handle(#require(URL(string: address))) == expected)
    }

    @Test func allowedSchemesApplyThroughProtocol() throws {
        var router: any PathwaysProviding = PathwayRouter()
        router.allowedSchemes = ["myapp"]
        router.register(host: "products", path: "/", matching: .prefix, supportFragmentParams: false) { _ in }
        #expect(try router.handle(#require(URL(string: "myapp://products/42"))))
        #expect(try router.handle(#require(URL(string: "https://products/42"))) == false)
    }
}

@MainActor struct HostlessURLTests {
    private struct ProductRoute: Pathway {
        static let pattern = "/products/:productID"
        let productID: Int
    }

    @Test(arguments: [PathwayMatchPolicy.prefix, .exact])
    func hostlessURLReachesHostlessTypedRegistration(_ policy: PathwayMatchPolicy) throws {
        var router = PathwayRouter()
        var received: Int?
        router.register(ProductRoute.self, matching: policy) { route, _ in received = route.productID }

        #expect(try router.handle(#require(URL(string: "myapp:///products/42"))))
        #expect(received == 42)
    }

    @Test func hostlessURLReachesHostlessPathRegistration() throws {
        var router: any PathwaysProviding = PathwayRouter()
        var received: [String: String]?
        router.register(path: "/settings") { received = $0 }

        #expect(try router.handle(#require(URL(string: "myapp:///settings/privacy?tab=a"))))
        #expect(received == ["tab": "a"])
    }

    @Test func hostlessURLIsRejectedWhenTheBaseHostIsSet() throws {
        var router = PathwayRouter()
        router.baseHost = "example.com"
        router.register(path: "/settings") { _ in Issue.record("hostless URL admitted for a base host") }

        #expect(try router.handle(#require(URL(string: "myapp:///settings"))) == false)
    }

    @Test func hostSpecificRegistrationsNeverMatchAHostlessURL() throws {
        var router = PathwayRouter()
        router.register(host: "", path: "/settings") { _ in Issue.record("empty host matched a hostless URL") }
        router.register(host: "products", path: "/settings") { _ in Issue.record("host matched a hostless URL") }
        router.register(host: "products", ProductRoute.self) { _, _ in Issue.record("host matched a hostless URL") }

        #expect(try router.handle(#require(URL(string: "myapp:///settings"))) == false)
        #expect(try router.handle(#require(URL(string: "myapp:///products/42"))) == false)
    }

    @Test func hostlessURLSkipsHostSpecificRegistrationsForTheSamePath() throws {
        var router = PathwayRouter()
        var selected: [String] = []
        router.register(host: "products", path: "/settings") { _ in selected.append("host") }
        router.register(path: "/settings") { _ in selected.append("hostless") }

        #expect(try router.handle(#require(URL(string: "myapp:///settings"))))
        #expect(try router.handle(#require(URL(string: "myapp://products/settings"))))
        #expect(selected == ["hostless", "host"])
    }

    @Test(arguments: [("myapp:///settings", true), ("MYAPP:///settings", true), ("other:///settings", false)])
    func schemeAllowlistAppliesToHostlessURLs(address: String, expected: Bool) throws {
        var router = PathwayRouter()
        router.allowedSchemes = ["myapp"]
        router.register(path: "/settings") { _ in }

        #expect(try router.handle(#require(URL(string: address))) == expected)
    }

    @Test func relativeURLWithoutSchemeIsNotRouted() throws {
        var router = PathwayRouter()
        router.register(path: "/settings") { _ in Issue.record("relative URL routed") }

        #expect(try router.handle(#require(URL(string: "/settings"))) == false)
    }
}
