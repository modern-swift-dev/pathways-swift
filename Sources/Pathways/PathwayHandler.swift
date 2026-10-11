/// The body of a registered handler, synchronous or asynchronous.
///
/// The ``PathwaysProviding`` registration conveniences create this value from
/// a closure, so most callers never name it. Typed registrations receive the
/// decoded route; path registrations use `PathwayHandler<Void>`.
public enum PathwayHandler<Route>: Sendable {

    /// A handler that runs synchronously on the main actor.
    case sync(@MainActor @Sendable (Route, PathwayRequest) -> PathwayHandlerResult)

    /// A handler that runs asynchronously on the main actor.
    ///
    /// Only the async `handle(_:)` of ``PathwaysProviding`` can run it.
    case async(@MainActor @Sendable (Route, PathwayRequest) async -> PathwayHandlerResult)
}

extension PathwayHandler {
    var isAsync: Bool {
        if case .async = self {
            return true
        }
        return false
    }

    /// The router checks ``isAsync`` first; throwing keeps a mistake from
    /// silently skipping the handler.
    @MainActor func callAsFunction(_ route: Route, _ request: PathwayRequest) throws -> PathwayHandlerResult {
        switch self {
            case let .sync(body):
                body(route, request)
            case .async:
                throw PathwayRouterError.asyncHandlerRequiresAsyncHandle
        }
    }

    @MainActor func callAsFunction(_ route: Route, _ request: PathwayRequest) async -> PathwayHandlerResult {
        switch self {
            case let .sync(body):
                body(route, request)
            case let .async(body):
                await body(route, request)
        }
    }
}
