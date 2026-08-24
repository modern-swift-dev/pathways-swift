/// Controls how a registered route matches an incoming URL path.
public enum PathwayMatchPolicy: Sendable {

    /// Matches when the registered path is a prefix of the incoming path.
    ///
    /// This preserves Pathways' original routing behavior. Typed placeholders
    /// can match more than one path component.
    case prefix

    /// Matches only when the complete normalized URL path matches the route.
    ///
    /// Typed placeholders match exactly one non-empty path component.
    case exact
}
