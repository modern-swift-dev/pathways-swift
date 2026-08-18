import Foundation
import Pathways

enum AccountKind: String, Codable, Sendable {
    case personal
    case business
}

struct AccountRoute: Pathway {
    static let pattern = "/accounts/:accountID/:kind"

    let accountID: Int
    let kind: AccountKind
}

let route = AccountRoute(accountID: 42, kind: .business)
let path = try PathwayEncoder.shared.encode(route)
print("Encoded path: \(path)")

guard let url = URL(string: "https://example.com\(path)") else {
    preconditionFailure("The example URL must be valid")
}

let decoded = try PathwayDecoder.shared.decode(AccountRoute.self, from: url)
print("Decoded account: \(decoded.accountID) (\(decoded.kind.rawValue))")
