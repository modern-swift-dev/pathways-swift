/// Errors reported while routing a URL.
public enum PathwayRouterError: Error, Equatable, CustomStringConvertible {

    /// The synchronous `handle(_:)` of ``PathwaysProviding`` selected an
    /// asynchronous handler, which only the async `handle(_:)` can run.
    ///
    /// The synchronous `handle(_:)` throws this instead of skipping the
    /// handler. Route the URL with `try await handle(_:)`.
    case asyncHandlerRequiresAsyncHandle

    /// A readable description of the failure, suitable for logging.
    public var description: String {
        switch self {
            case .asyncHandlerRequiresAsyncHandle:
                "The selected handler is asynchronous; call the async handle(_:) instead."
        }
    }
}
