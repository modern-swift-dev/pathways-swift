---
title: "Examples | Pathways"
description: "Buildable Pathways example packages."
---

<a id="content"></a>

Examples

# Small packages you can run.

Each example is an independent Swift package that depends on the repository root.

## CodableRoutes

Define a `Pathway` model, encode it into a path, and decode it from a URL.

```swift
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

guard let url = URL(string: "https://example.com\(path)") else {
    preconditionFailure("The example URL must be valid")
}

let decoded = try PathwayDecoder.shared.decode(AccountRoute.self, from: url)
print("Decoded account: \(decoded.accountID) (\(decoded.kind.rawValue))")
```

```shell
cd Examples/CodableRoutes
swift run
```

[View complete source →](https://github.com/modern-swift-dev/pathways-swift/blob/main/Examples/CodableRoutes/Sources/CodableRoutesExample/main.swift)

## RoutingCenter

Register typed and path-only routes, filter by exact host, read query parameters, and inspect the result from `handle(_:)`.

```swift
import Foundation
import Pathways

struct ProductRoute: Pathway {
    static let pattern = "/products/:productID"

    let productID: Int
}

@main enum RoutingCenterExample {
  @MainActor static func main() throws {
    var router = Pathways()

    router.register(host: "example.com", ProductRoute.self) { route, query in
        let campaign = query["campaign", default: "none"]
        print("Open product \(route.productID); campaign: \(campaign)")
    }

    router.register(host: "example.com", path: "/settings") { query in
        let tab = query["tab", default: "general"]
        print("Open settings tab: \(tab)")
    }

    let url = URL(string: "https://example.com/products/42?campaign=summer")!
    let handled = try router.handle(url)
    print("Handled: \(handled)")
  }
}
```

```shell
cd Examples/RoutingCenter
swift run
```

[View complete source →](https://github.com/modern-swift-dev/pathways-swift/blob/main/Examples/RoutingCenter/Sources/RoutingCenterExample/main.swift)
