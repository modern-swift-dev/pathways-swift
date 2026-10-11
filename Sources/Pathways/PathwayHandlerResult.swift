/// Whether a handler handled the URL it was invoked for.
///
/// Return ``declined`` from a request handler when it cannot handle this URL
/// at runtime, for example while a feature flag is off. The router then tries
/// the next most specific matching registration.
public enum PathwayHandlerResult: Sendable {

    /// The handler handled the URL, so routing stops.
    case handled

    /// The handler declined the URL, so routing falls through to the next
    /// most specific matching registration.
    case declined
}
