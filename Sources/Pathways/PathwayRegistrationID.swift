import Foundation

/// Identifies one registration so it can be removed with
/// ``PathwaysProviding/unregister(_:)``.
///
/// Every registration receives a distinct identifier, including across copies
/// of a router.
public struct PathwayRegistrationID: Hashable, Sendable {
    private let rawValue = UUID()

    init() {}
}
