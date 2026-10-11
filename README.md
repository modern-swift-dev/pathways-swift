# Pathways

Pathways is a small, dependency-free Swift package for defining typed deep-link paths, converting those paths to and from Codable values, and dispatching incoming URLs to main-actor handlers.

```swift
struct ProductRoute: Pathway {
    static let pattern = "/products/:productID"

    let productID: Int
}

var router = PathwayRouter()
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
- Swift 6 concurrency annotations and main-actor handler execution, with synchronous or `async` handlers
- A SwiftUI modifier that routes opened URLs
- No third-party runtime dependencies

## Requirements

- Swift 6.0 or newer
- macOS 13 or newer
- iOS 16 or newer
- tvOS 16 or newer
- watchOS 9 or newer
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
var router = PathwayRouter()

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

Supported scalar values include strings, booleans, integer and floating-point types, raw-value Codable enums, UUIDs, and ISO 8601 dates with millisecond precision. Nested values and collections are not supported.

### Query fields

A field whose coding key is not a pattern placeholder maps to the same-named query parameter. Decoding reads it from the URL's query, and encoding writes it as a query item, so an encoded URL decodes back to an equal model:

```swift
struct SearchRoute: Pathway {
    static let pattern = "/search/:category"

    let category: String
    let page: Int
    let campaign: String?
}

let path = try PathwayEncoder.shared.encode(SearchRoute(category: "books", page: 2, campaign: nil))
// /search/books?page=2

let url = URL(string: "https://example.com/search/books?page=2&campaign=summer")!
let route = try PathwayDecoder.shared.decode(SearchRoute.self, from: url)
// route.page == 2, route.campaign == "summer"
```

Query fields support the same scalar types as placeholders. An optional field may be absent: it decodes as `nil`, and encoding omits it. A missing required field throws `PathwayError.notFound(key:)` naming the key. Unlike a path component, a query value may be empty, so `?campaign=` decodes as an empty string. When a name repeats, the last value wins. Typed handlers receive the model with its query fields populated; the query parameters are also still delivered to the handler.

## Path-only routing

Register a path directly when no typed path values are needed:

```swift
router.register(host: "example.com", path: "/settings") { query in
    navigateToSettings(tab: query["tab"])
}
```

Path-only registrations use prefix matching by default, so `/settings` also matches `/settings/privacy`. Prefixes match whole path components, so `/settings` does not match `/settings-legacy`. Pass `matching: .exact` when the complete normalized path must match:

```swift
router.register(host: "example.com", path: "/settings", matching: .exact) { query in
    navigateToSettings(tab: query["tab"])
}
```

Exact matching also applies to typed routes. With either policy, each `:` placeholder matches exactly one non-empty path component.

When several registrations match a URL, the most specific one runs. At the first path component where two patterns differ, a literal beats a `:` placeholder, so `/products/featured` wins over `/products/:productID`. Otherwise the longer pattern wins, then exact matching beats prefix matching, then a host-specific registration beats a hostless one. Equally specific registrations keep the first one registered. When the selected handler declines the URL, routing falls through to the next registration in that order.

## Removing routes

Every registration returns a discardable `PathwayRegistrationID`. Pass it to `unregister(_:)` to remove just that registration, such as when a feature or screen goes away; `reset()` removes every registration:

```swift
let registration = router.register(host: "example.com", path: "/promotions") { _ in
    showPromotions()
}

router.unregister(registration)
```

Other registrations, including those for the same pattern, keep working. Unregistering an unknown or already-removed identifier does nothing.

## Hosts and schemes

Hosts are compared case-insensitively. Every scheme is accepted by default; restrict it when the same path must not be reachable through another scheme:

```swift
router.allowedSchemes = ["https"]
```

### Custom-scheme URLs

Custom-scheme deep links come in two shapes, and each needs its own registration:

- `myapp://products/42` has a host. Foundation parses `products` as the host and `/42` as the path, so register for that host with a pattern that starts after it:

  ```swift
  struct ProductIDRoute: Pathway {
      static let pattern = "/:productID"

      let productID: Int
  }

  router.register(host: "products", ProductIDRoute.self) { route, _ in
      navigateToProduct(id: route.productID)
  }
  ```

- `myapp:///products/42` has no host, and its whole path is `/products/42`. A URL without a host only reaches hostless registrations, and only while `baseHost` is empty (the default):

  ```swift
  router.register(ProductRoute.self) { route, _ in
      navigateToProduct(id: route.productID)
  }
  ```

Host-specific registrations never match a URL without a host, and `allowedSchemes` applies to both shapes.

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

A parameter without a value, such as `?debug`, is delivered as an empty string. When a name repeats, the last value wins. A `+` stays a literal plus sign, so percent-encode spaces as `%20`.

### Request handlers

A handler can receive a `PathwayRequest` instead of the parameter dictionary. The request carries the original URL, the same `parameters` dictionary, and the ordered `queryItems`, which keep every value of a repeated name and leave valueless flags with a `nil` value. A request handler returns whether it handled the URL:

```swift
router.register(host: "example.com", ProductRoute.self) { route, request in
    analytics.log(opened: request.url)
    let tags = request.queryItems.filter { $0.name == "tag" }.compactMap(\.value)
    navigateToProduct(id: route.productID, tags: tags)
    return .handled
}

router.register(host: "example.com", path: "/search") { request in
    search(terms: request.queryItems.filter { $0.name == "q" }.compactMap(\.value))
    return .handled
}
```

When fragment parameters are enabled for the registration, the fragment's query items follow the standard ones.

### Declining a URL

A request handler can decide at runtime that it cannot handle a URL, for example while a feature flag is off. Return `.declined` and the router tries the next most specific matching registration; return `.handled` to stop:

```swift
router.register(host: "example.com", path: "/checkout") { request in
    guard features.isCheckoutEnabled else {
        return .declined
    }
    openCheckout(request.url)
    return .handled
}
```

`handle(_:)` returns `false` when every matching handler declines. Handlers that receive the parameter dictionary don't return a result and always count as handled. Declining is the handler's choice only: a typed route that fails to decode still throws.

### Fallback

Give the router one place to handle links it could not route, such as showing a generic screen or opening the URL in a browser:

```swift
router.fallback = { request in
    openInBrowser(request.url)
}
```

The fallback runs when no registration matches the URL or every matching handler declines, and `handle(_:)` then returns `true`. It does not run for URLs rejected by `allowedSchemes` or whose host is not admitted, so `handle(_:)` still returns `false` for those, nor after a decode error, which still throws.

### Asynchronous handlers

A request handler that needs to await, for example to load data or wait for authentication, can be `async`. It can also decline based on that work. Route URLs with the async `handle(_:)`, which runs synchronous and asynchronous handlers with the same precedence, fall-through, and fallback:

```swift
router.register(host: "example.com", ProductRoute.self) { route, _ in
    guard let product = try? await catalog.product(id: route.productID) else {
        return .declined
    }
    show(product)
    return .handled
}

let handled = try await router.handle(url)
```

The synchronous `handle(_:)` never skips an asynchronous handler: when it selects one, it throws `PathwayRouterError.asyncHandlerRequiresAsyncHandle`. In an `async` context, Swift selects the async `handle(_:)`, so write `try await router.handle(url)`.

## SwiftUI

Where SwiftUI is available, route URLs opened in a view hierarchy with `onOpenURL(routingTo:onError:)`. It passes each URL to the router's async `handle(_:)`, so asynchronous handlers run, and reports routing errors to `onError` instead of discarding them:

```swift
@main
struct ShopApp: App {
    let router: PathwayRouter = {
        var router = PathwayRouter()
        router.register(host: "example.com", ProductRoute.self) { route, _ in
            navigateToProduct(id: route.productID)
        }
        return router
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL(routingTo: router) { error in
                    print("Could not route URL: \(error)")
                }
        }
    }
}
```

URLs that no registration handles are not errors; set the router's `fallback` to handle them. The modifier is compiled only where SwiftUI exists, so Linux builds are unaffected.

## Examples

The [Examples](Examples/README.md) directory contains standalone packages:

- [CodableRoutes](Examples/CodableRoutes/README.md) demonstrates model encoding and decoding.
- [RoutingCenter](Examples/RoutingCenter/README.md) demonstrates host-aware dispatch and query parameters.

Each can be run independently with `swift run` from its directory.

## Documentation

- [Guide](https://modern-swift-dev.github.io/docs/pathways-swift/)
- [Examples](https://modern-swift-dev.github.io/docs/pathways-swift/examples/)
- [API documentation](https://modern-swift-dev.github.io/docs/pathways-swift/documentation/pathways/)

## Contributing

Guides and examples live in [Documentation/Site](Documentation/Site). The [central documentation repository](https://github.com/modern-swift-dev/docs) owns the shared Astro theme, builds the guides and DocC API reference, and publishes them daily. For local builds and previews, follow the [docs README](https://github.com/modern-swift-dev/docs/blob/main/README.md).

See [CONTRIBUTING.md](CONTRIBUTING.md) for development and maintenance instructions.

## License

Pathways is available under the MIT License. See [LICENSE](LICENSE).
