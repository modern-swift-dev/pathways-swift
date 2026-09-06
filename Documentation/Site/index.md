---
title: "Pathways | Typed deep-link routing for Swift"
description: "A small Swift package for typed deep-link paths and URL routing."
---

<a id="content"></a>

Swift 6 deep-link routing

# URLs that keep their shape.

Pathways turns flat URL paths into Codable Swift values and sends incoming URLs to main-actor handlers.

[Get started](/docs/pathways-swift/documentation/getting-started/) [View source](https://github.com/modern-swift-dev/pathways-swift)

## Latest release

<a id="release-heading"></a>

{{version}}

Published {{releaseDate}}

Install from `{{version}}`

[Read release notes]({{releaseURL}})

A route is a value

## Define a typed route and register its handler.

Placeholders begin with `:` and map to Codable keys. The router validates the host and path, decodes the model, and invokes the matching main-actor handler.

```swift
import Pathways

struct ProductRoute: Pathway {
    static let pattern = "/products/:productID"

    let productID: Int
}

var router = Pathways()
router.register(host: "example.com", ProductRoute.self) { route, query in
    print("Open product \(route.productID)")
    print("Campaign: \(query["campaign"] ?? "none")")
}
```

### One model, two URL operations

| Operation | Value |
| --- | --- |
| Swift model | `ProductRoute(productID: 42)` |
| Encode | `/products/42` |
| Decode | `https://example.com/products/42` |

Installation

## Add the package.

Pathways has no third-party runtime dependencies. It requires Swift 6 and supports current Apple platforms.

```swift
.package(
    url: "https://github.com/modern-swift-dev/pathways-swift.git",
    from: "{{version}}"
)
```

## Typed paths

Decode path components as strings, numbers, UUIDs, dates, raw-value enums, and other supported scalar values.

## Host-aware routing

Register typed or path-only handlers and scope them to an exact URL host when needed.

## Query parameters

Handlers receive query parameters as a `[String: String]` dictionary.

Platform support

## Built for Swift 6.

Pathways uses Swift concurrency annotations and has no third-party runtime dependencies.

- macOS 15+

- iOS 18+

- tvOS 18+

- watchOS 10+

- visionOS 1+

Provenance

## Source, tests, and releases stay together.

The library, its executable examples, test suite, release history, guide source, and generated API reference all live in the canonical repository. Pathways is released under the MIT License.

[Build your first route](/docs/pathways-swift/documentation/getting-started/) [Browse the API](/docs/pathways-swift/documentation/pathways/) [Inspect the repository](https://github.com/modern-swift-dev/pathways-swift)
