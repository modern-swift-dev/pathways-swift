# Routing URLs

`Pathways` stores route handlers and invokes the first handler selected for an incoming URL.

## Typed handlers

Register a `Pathway` type when the path contains values that should be validated and decoded:

```swift
var router = Pathways()

router.register(host: "example.com", ProductRoute.self) { route, query in
    showProduct(id: route.productID, campaign: query["campaign"])
}
```

The closure receives the decoded model and a `[String: String]` dictionary of query parameters.

## Path-only handlers

Use a path handler when no typed path values are needed:

```swift
router.register(host: "example.com", path: "/settings") { query in
    showSettings(tab: query["tab"])
}
```

Path-only matching uses a path prefix. For example, `/settings` also matches `/settings/privacy`. Choose paths carefully to avoid unintended overlap.

## Hosts

Supplying `host:` scopes an individual handler to that exact URL host. Handlers registered without a host can be enabled for one shared host with `baseHost`:

```swift
var router = Pathways()
router.baseHost = "example.com"

router.register(path: "/help") { _ in
    showHelp()
}
```

An incoming URL must have a host found in `baseHost` or in a host-scoped registration. Host comparison is exact.

## Query and fragment parameters

Handlers receive normal query parameters by default:

```text
https://example.com/products/42?campaign=summer
```

Set `supportFragmentParams: true` to merge parameters embedded after a fragment route into the handler dictionary:

```swift
router.register(
    host: "example.com",
    path: "/callback/#complete",
    supportFragmentParams: true
) { parameters in
    finishSignIn(token: parameters["token"])
}
```

This matches URLs shaped like `https://example.com/callback#complete?token=abc`. Fragment parameter support is experimental. If query and fragment parameters share a name, the later fragment value wins when converted to the dictionary.

## Handling and lifecycle

Call `handle(_:)` on the main actor. It returns whether a handler ran and rethrows decoding errors:

```swift
do {
    if try router.handle(url) == false {
        showUnsupportedLinkMessage()
    }
} catch {
    reportInvalidLink(error)
}
```

Use `registeredHosts()` and `registeredPatterns()` for inspection. Call `reset()` to remove every handler.

Avoid overlapping patterns where possible. When several handlers match, the current implementation orders candidates by their pattern strings; registration order is not a stable precedence mechanism.

## SwiftUI integration

Keep a configured routing center in app-owned state and pass URLs from `onOpenURL`:

```swift
.onOpenURL { url in
    do {
        _ = try router.handle(url)
    } catch {
        // Report or present an invalid-link state.
    }
}
```

Both registration closures and `handle(_:)` are main-actor isolated, making them suitable for UI navigation updates.
