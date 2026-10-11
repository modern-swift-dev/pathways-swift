/// Controls how a registered route matches an incoming URL path.
public enum PathwayMatchPolicy: Sendable {

    /// Matches when the registered path's components are the leading
    /// components of the incoming path.
    ///
    /// Typed placeholders match exactly one non-empty path component, and any
    /// components after the registered path are ignored.
    case prefix

    /// Matches only when the complete normalized URL path matches the route.
    ///
    /// Typed placeholders match exactly one non-empty path component.
    case exact
}
