#if canImport(SwiftUI)
    import SwiftUI

    public extension View {
        /// Routes URLs opened in this view hierarchy to a router.
        ///
        /// Each URL delivered to `onOpenURL` is passed to the router's async
        /// `handle(_:)` in a main-actor task, so asynchronous handlers run.
        /// The modifier routes with the router value supplied when the view's
        /// body is evaluated.
        ///
        /// ```swift
        /// ContentView()
        ///     .onOpenURL(routingTo: router) { error in
        ///         logger.error("Could not route URL: \(error)")
        ///     }
        /// ```
        ///
        /// - Parameters:
        ///   - router: The router that handles opened URLs.
        ///   - onError: Called on the main actor with any error thrown while
        ///     routing, such as a ``PathwayError`` from a typed route that
        ///     cannot be decoded. URLs that no registration handles are not
        ///     errors; use the router's ``PathwaysProviding/fallback`` for them.
        /// - Returns: A view that routes opened URLs.
        func onOpenURL(
            routingTo router: some PathwaysProviding,
            onError: @escaping @MainActor @Sendable (any Error) -> Void
        ) -> some View {
            onOpenURL { url in
                Task { @MainActor in
                    await routeOpenedURL(url, with: router, onError: onError)
                }
            }
        }
    }

    @MainActor func routeOpenedURL(
        _ url: URL,
        with router: some PathwaysProviding,
        onError: @MainActor (any Error) -> Void
    ) async {
        do {
            _ = try await router.handle(url)
        } catch {
            onError(error)
        }
    }
#endif
