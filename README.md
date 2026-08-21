# Pathways

Pathways is a small, dependency-free Swift package for defining typed deep-link paths, converting those paths to and from Codable values, and dispatching incoming URLs to main-actor handlers.

```swift
struct ProductRoute: Pathway {
    static let pattern = "/products/:productID"

    let productID: Int
}

var router = Pathways()
router.register(host: "example.com", ProductRoute.self) { route, query in
    print("Open product \(route.productID)")
    print("Campaign: \(query["campaign"] ?? "none")")
}

let url = URL(string: "https://example.com/products/42?campaign=summer")!
try router.handle(url)
```

## Features

- Strongly typed URL path parameters through Swift `Codable`
- Encoding models into percent-escaped URL paths
- Decoding URL paths into application-defined models
- Typed and path-only routing handlers
- Optional exact-host filtering
- Query parameter delivery to handlers
- Experimental fragment-route and fragment-parameter support
- Swift 6 concurrency annotations and main-actor handler execution
- No third-party runtime dependencies

## Requirements

- Swift 6.0 or newer
- macOS 15 or newer
- iOS 18 or newer
- tvOS 18 or newer
- watchOS 10 or newer
- visionOS 1 or newer

## Installation

In Xcode, use **File > Add Package Dependencies** and enter:

```text
https://github.com/modern-swift-dev/pathways-swift.git
```

Or add the package in `Package.swift`:

```swift
dependencies: [
    .package(
        url: "https://github.com/modern-swift-dev/pathways-swift.git",
        from: "1.0.0"
    )
]
```

Add `Pathways` to the target that uses it:

```swift
.target(
    name: "YourTarget",
    dependencies: [
        .product(name: "Pathways", package: "pathways-swift")
    ]
)
```

## Quick start

### 1. Define a route

Adopt `Pathway` and declare a path pattern. Placeholder names begin with `:` and correspond to Codable keys.

```swift
import Pathways

struct ProductRoute: Pathway {
    static let pattern = "/products/:productID"

    let productID: Int
}
```

### 2. Encode and decode

```swift
import Foundation
import Pathways

let path = try PathwayEncoder.shared.encode(ProductRoute(productID: 42))
// /products/42

let url = URL(string: "https://example.com/products/42")!
let route = try PathwayDecoder.shared.decode(ProductRoute.self, from: url)
// route.productID == 42
```

### 3. Register a handler

```swift
var router = Pathways()

router.register(host: "example.com", ProductRoute.self) { route, query in
    navigateToProduct(id: route.productID, campaign: query["campaign"])
}

let handled = try router.handle(url)
```

The handler executes on the main actor. `handle(_:)` returns `false` when no route matches and throws when a matched typed route cannot be decoded.

## Route patterns

Patterns contain literal path components and named placeholders:

```text
/teams/:teamID/members/:memberID
```

The model stays flat and each placeholder maps to a Codable key:

```swift
struct MemberRoute: Pathway {
    static let pattern = "/teams/:team_id/members/:member_id"

    let teamID: Int
    let memberID: UUID

    enum CodingKeys: String, CodingKey {
        case teamID = "team_id"
        case memberID = "member_id"
    }
}
```

Supported scalar values include strings, booleans, integer and floating-point types, raw-value Codable enums, UUIDs, and ISO 8601 dates. Nested values and collections are not supported.

## Path-only routing

Register a path directly when no typed path values are needed:

```swift
router.register(host: "example.com", path: "/settings") { query in
    navigateToSettings(tab: query["tab"])
}
```

Path-only registrations use prefix matching, so `/settings` also matches `/settings/privacy`.

## Query and fragment parameters

Handler dictionaries contain standard query parameters by default. For URLs that encode a route and parameters in the fragment, opt in per registration:

```swift
router.register(
    host: "example.com",
    path: "/callback/#complete",
    supportFragmentParams: true
) { parameters in
    completeSignIn(token: parameters["token"])
}
```

This supports a URL such as `https://example.com/callback#complete?token=abc`. Fragment handling is experimental.

## Examples

The [Examples](Examples/README.md) directory contains standalone packages:

- [CodableRoutes](Examples/CodableRoutes/README.md) demonstrates model encoding and decoding.
- [RoutingCenter](Examples/RoutingCenter/README.md) demonstrates host-aware dispatch and query parameters.

Each can be run independently with `swift run` from its directory.

## Documentation

- [Guide](https://modern-swift-dev.github.io/pathways-swift/)
- [Examples](https://modern-swift-dev.github.io/pathways-swift/examples/)
- [API documentation](https://modern-swift-dev.github.io/pathways-swift/documentation/pathways/)

## Development

Run the macOS test suite from the repository root:

```sh
swift test
```

Build the examples independently:

```sh
swift build --package-path Examples/CodableRoutes
swift build --package-path Examples/RoutingCenter
```

The repository's `Makefile` also provides formatting, linting, and platform-specific test targets. Development tool versions are managed through Mint and Homebrew files in the repository.

## Maintainers

The website source lives in `Website/`. Generated documentation is written to `docs/` and committed to the repository.

To work on the website locally:

```sh
make site-setup
make site-preview
make site-validate
make site-build
```

To publish a release, publish the GitHub release first, then run `make site-build`. Review the rendered latest release and the DocC changes before committing the generated `docs/` directory.

For the one-time GitHub Pages setup, open **Settings > Pages**, choose **Deploy from a branch**, select `main` and `/docs`, then save. See the [GitHub Pages publishing-source guide](https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site).

## License

Pathways is available under the MIT License. See [LICENSE](LICENSE).
