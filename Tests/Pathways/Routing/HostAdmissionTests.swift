import Foundation
import Pathways
import Testing

@MainActor struct HostAdmissionTests {
    @Test func hostlessRegistrationAcceptsDeclaredHostsAndCurrentBaseHost() throws {
        var router = Pathways()
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
