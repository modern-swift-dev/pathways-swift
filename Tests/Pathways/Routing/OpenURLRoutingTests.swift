#if canImport(SwiftUI)
    import Foundation
    @testable import Pathways
    import SwiftUI
    import Testing

    @MainActor struct OpenURLRoutingTests {
        @Test func openedURLsUseTheAsyncHandlingPath() async throws {
            var router = PathwayRouter()
            router.baseHost = "localhost"
            var loaded: Int?
            router.register(TestSingleFieldPathway.self) { route, _ in
                await Task.yield()
                loaded = route.id
                return .handled
            }

            try await routeOpenedURL(#require(URL(string: "https://localhost/user/5")), with: router) { error in
                Issue.record("Unexpected error: \(error)")
            }

            #expect(loaded == 5)
        }

        @Test func routingErrorsReachTheErrorHook() async throws {
            var router: any PathwaysProviding = PathwayRouter()
            router.baseHost = "localhost"
            router.register(TestSingleFieldPathway.self) { _, _ in Issue.record("handler invoked for an undecodable route") }
            var errors: [PathwayError] = []

            try await routeOpenedURL(#require(URL(string: "https://localhost/user/abc")), with: router) { error in
                errors.append(error as? PathwayError ?? .unsupported)
            }

            #expect(errors == [.notDecodable(key: "id", value: "abc")])
        }

        /// Compiling is the assertion: the modifier is available on any view.
        @Test func modifierIsAvailableOnViews() {
            var router = PathwayRouter()
            router.register(path: "/settings") { _ in }

            _ = Text("Content").onOpenURL(routingTo: router) { _ in }
        }
    }
#endif
