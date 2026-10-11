import Foundation
import Pathways
import Testing

/// Compiles the code samples in Documentation/Site/documentation/migrating-to-2
/// against the 2.0 API. Keep the two in sync.
@MainActor struct MigrationGuideTests {
    @Test func routerRename() throws {
        var router = PathwayRouter()
        router.register(host: "example.com", path: "/a") { _ in }
        #expect(try router.handle(#require(URL(string: "https://example.com/a"))))
    }

    @Test func awaitHandleInAsynchronousCode() async throws {
        var router = PathwayRouter()
        router.register(host: "example.com", path: "/a") { _ in }

        @MainActor func open(_ url: URL) async throws -> Bool {
            try await router.handle(url)
        }

        #expect(try await open(#require(URL(string: "https://example.com/a"))))
    }

    @Test func valuelessParametersAndQueryItems() throws {
        var router = PathwayRouter()

        router.register(host: "example.com", path: "/search") { request in
            let isDebug = request.parameters["debug"] != nil
            let tags = request.queryItems.filter { $0.name == "tag" }.compactMap(\.value)
            print("Debug: \(isDebug), tags: \(tags)")
            return .handled
        }

        #expect(try router.handle(#require(URL(string: "https://example.com/search?debug&tag=a&tag=b"))))
    }

    struct SearchRoute: Pathway {
        static let pattern = "/search/:category"

        let category: String
        let page: Int
        let campaign: String?
    }

    @Test func nonPlaceholderFieldsMapToQueryParameters() throws {
        let path = try PathwayEncoder.shared.encode(SearchRoute(category: "books", page: 2, campaign: nil))
        #expect(path == "/search/books?page=2")
    }

    @Test func errorsIdentifyTheFailingKey() {
        var missingKeys: [String?] = []
        func showMissingValue(named key: String?) {
            missingKeys.append(key)
        }
        let error: any Error = PathwayError.notFound(key: "page")

        if case let .notFound(key) = error as? PathwayError {
            showMissingValue(named: key)
        }

        #expect(missingKeys == ["page"])
    }

    @Test func kindOnlyPatternsKeepWorking() throws {
        var caught: [String] = []
        do {
            _ = try PathwayDecoder.shared.decode(TestSingleFieldPathway.self, from: #require(URL(string: "https://localhost/user/abc")))
        } catch PathwayError.notDecodable {
            caught.append("notDecodable")
        }
        switch PathwayError.notFound(key: "id") {
            case .notFound:
                caught.append("notFound")
            default:
                break
        }
        #expect(caught == ["notDecodable", "notFound"])
    }

    struct LoggingRouter: PathwaysProviding {
        private var router = PathwayRouter()

        var baseHost: String {
            get { router.baseHost }
            set { router.baseHost = newValue }
        }

        var allowedSchemes: Set<String>? {
            get { router.allowedSchemes }
            set { router.allowedSchemes = newValue }
        }

        var fallback: (@MainActor @Sendable (PathwayRequest) -> Void)? {
            get { router.fallback }
            set { router.fallback = newValue }
        }

        @discardableResult
        mutating func register<T: Pathway>(
            host: String?,
            _ type: T.Type,
            matching: PathwayMatchPolicy,
            supportFragmentParams: Bool,
            handler: PathwayHandler<T>
        ) -> PathwayRegistrationID {
            router.register(host: host, type, matching: matching, supportFragmentParams: supportFragmentParams, handler: handler)
        }

        @discardableResult
        mutating func register(
            host: String?,
            path: String,
            matching: PathwayMatchPolicy,
            supportFragmentParams: Bool,
            handler: PathwayHandler<Void>
        ) -> PathwayRegistrationID {
            router.register(host: host, path: path, matching: matching, supportFragmentParams: supportFragmentParams, handler: handler)
        }

        @MainActor func handle(_ url: URL) throws -> Bool {
            print("Routing \(url)")
            return try router.handle(url)
        }

        @MainActor func handle(_ url: URL) async throws -> Bool {
            print("Routing \(url)")
            return try await router.handle(url)
        }

        mutating func unregister(_ registration: PathwayRegistrationID) {
            router.unregister(registration)
        }

        mutating func reset() {
            router.reset()
        }

        func registeredHosts() -> [String] {
            router.registeredHosts()
        }

        func registeredPatterns() -> [String] {
            router.registeredPatterns()
        }
    }

    @Test func customConformanceGetsEveryConvenience() async throws {
        var router = LoggingRouter()
        router.baseHost = "localhost"
        var visited: [String] = []
        router.register(TestSingleFieldPathway.self) { route, _ in visited.append("typed \(route.id)") }
        let removed = router.register(path: "/a") { _ in visited.append("removed") }
        router.register(host: "localhost", path: "/a") { request in
            await Task.yield()
            visited.append("async \(request.url.path)")
            return .handled
        }
        router.unregister(removed)

        #expect(try await router.handle(#require(URL(string: "https://localhost/user/3"))))
        #expect(try await router.handle(#require(URL(string: "https://localhost/a"))))
        #expect(visited == ["typed 3", "async /a"])
        #expect(router.registeredHosts() == ["localhost"])
    }
}
