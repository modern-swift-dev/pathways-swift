---
title: "Migrating to 2.0 | Pathways"
description: "Every breaking change in Pathways 2.0 and how to update your code."
---

<a id="content"></a>

Documentation

# Migrating to 2.0

Pathways 2.0 matches URLs more strictly, reports richer errors, and grows the router API. This guide lists every breaking change since 1.1.2: what changed, why, and what you must do. Entries marked **No action** change behavior without requiring code edits, but check them against code that relied on the old behavior.

## Update the dependency

```swift
.package(
    url: "https://github.com/modern-swift-dev/pathways-swift.git",
    from: "2.0.0"
)
```

### Lower deployment targets

**What changed:** 1.1.2 required macOS 15, iOS 18, tvOS 18, and watchOS 10. 2.0 supports macOS 13, iOS 16, tvOS 16, watchOS 9, and visionOS 1.

**Why:** Nothing in the package needs the newer releases; these are the first releases with every Foundation API the package uses.

**What to do:** **No action.** Apps can now adopt Pathways on older systems.

## Router

### `Pathways` is now `PathwayRouter`

**What changed:** The router type is renamed from `Pathways` to `PathwayRouter`.

**Why:** The type shared the module's name, so module-qualified names such as `Pathways.PathwayError` failed to resolve.

**What to do:** Replace `Pathways()` with `PathwayRouter()`, and update type annotations.

```swift
// 1.1.2
var router = Pathways()

// 2.0
var router = PathwayRouter()
```

### Await `handle(_:)` in asynchronous code

**What changed:** Routers gain an async `handle(_:)` beside the synchronous one, so handlers can `await`. In an `async` context, such as a `Task` or an `async` function, Swift selects the async overload, and `try router.handle(url)` no longer compiles: "expression is 'async' but is not marked with 'await'".

**Why:** Asynchronous handlers, for example ones that load data before navigating, need an asynchronous entry point. The synchronous `handle(_:)` stays for synchronous callers.

**What to do:** Write `try await router.handle(url)` in asynchronous code. The async `handle(_:)` runs synchronous handlers exactly as the synchronous one does. Synchronous code needs no change.

```swift
// 1.1.2
@MainActor func open(_ url: URL) async throws -> Bool {
    try router.handle(url)
}

// 2.0
@MainActor func open(_ url: URL) async throws -> Bool {
    try await router.handle(url)
}
```

The synchronous `handle(_:)` never skips an asynchronous handler: when it selects one, it throws `PathwayRouterError.asyncHandlerRequiresAsyncHandle`. This only affects code that registers asynchronous handlers.

### URLs without a host are routed

**What changed:** A URL without a host, such as `myapp:///products/42`, was always rejected. It now reaches hostless registrations while `baseHost` is empty. Host-specific registrations never match it.

**Why:** Custom-scheme deep links often take this shape, and there was no way to route them.

**What to do:** Nothing, unless you relied on such URLs being rejected. In that case set `baseHost`, restrict `allowedSchemes`, or register the routes for a specific host.

### `register` returns a registration identifier

**What changed:** Every `register` call returns a `PathwayRegistrationID` that `unregister(_:)` accepts to remove just that registration.

**Why:** Apps that register routes per feature or screen can remove their own routes without `reset()`.

**What to do:** **No action.** The result is discardable, so existing calls compile without warnings.

### Unrouted URLs can reach a fallback

**What changed:** A router can be given an optional `fallback` that receives URLs no registration handles. When it runs, `handle(_:)` returns `true`.

**Why:** Apps want one place to handle links they cannot route.

**What to do:** **No action.** Without a fallback, `handle(_:)` returns `false` for unmatched URLs as before.

## Matching and precedence

### Prefixes match whole path components

**What changed:** Prefix matching compared raw strings, so `/settings` also matched `/settings-legacy`, and `/about` matched `/aboutus`. A prefix now ends on a path component boundary, for path and typed registrations alike.

**Why:** A registration for `/settings` should not handle an unrelated route that only shares its spelling.

**What to do:** Register each route that relied on a partial-component match separately, or use a placeholder.

### Each placeholder matches exactly one path component

**What changed:** Under the default prefix policy, a placeholder could span several path components, so `/users/:id/posts/:postID` matched `/users/1/2/posts/3` and decoded `postID` as `"posts"`. A placeholder now matches exactly one non-empty component under both policies.

**Why:** The decoder reads values by position, so spanning placeholders produced wrong values.

**What to do:** Nothing for well-formed URLs. URLs with extra components inside a pattern no longer match it.

### Registered paths are normalized

**What changed:** Registrations such as `"/settings/"` or `"settings"` never matched, because the registered path kept its slashes verbatim. Registered paths are now normalized like incoming URLs.

**Why:** Trailing or missing slashes in a registration are not meaningful.

**What to do:** **No action.** Registrations that never matched now match.

### The most specific registration wins

**What changed:** Precedence compared pattern strings, and `:` sorts after digits, `-`, and `.`, so a typed `/v/:id` could beat a literal `/v/2`. Matching registrations are now ranked by specificity: at the first path component where two patterns differ, a literal beats a placeholder; otherwise the longer pattern wins, then exact matching beats prefix matching, then a host-specific registration beats a hostless one. Equally specific registrations keep the first one registered.

**Why:** The previous order depended on character sorting rather than on what a pattern matches.

**What to do:** Review routes whose patterns overlap. If the wrong handler runs, make the intended one more specific, for example with a literal component or `matching: .exact`.

### Schemes can be restricted

**What changed:** The router ignored the URL scheme, so `ftp://example.com/a` reached the same handler as `https://example.com/a`. Routers gain `allowedSchemes`, compared case-insensitively. URLs whose scheme is not listed are rejected: `handle(_:)` returns `false` and the fallback does not run.

**Why:** A path should not be reachable through a scheme the app never meant to accept.

**What to do:** **No action** for routers: the default, `nil`, accepts any scheme as before. To restrict routing, set `router.allowedSchemes = ["https"]`. Custom `PathwaysProviding` conformances must implement the new property (see below).

### Hosts compare case-insensitively

**What changed:** `https://EXAMPLE.com/a` was rejected for a registration on `example.com`. Registered hosts, `baseHost`, and incoming hosts are now compared case-insensitively, and `registeredHosts()` returns lowercased hosts.

**Why:** URL hosts are case-insensitive.

**What to do:** Compare `registeredHosts()` results against lowercased hosts.

### Handlers can decline

**What changed:** A request handler can return `.declined`, and routing falls through to the next most specific matching registration. `handle(_:)` returns `false` when every match declines.

**Why:** A handler may decide at runtime that it cannot handle a URL, for example while a feature flag is off.

**What to do:** **No action.** Handlers that receive the parameter dictionary don't return a result and always count as handled.

## Parameters

### Valueless parameters are empty strings

**What changed:** A parameter without a value, such as `?debug`, disappeared from the handler's dictionary, and a later valueless `name` even removed an earlier `name=value`. Valueless parameters are now delivered as empty strings, in query and fragment parameters alike.

**Why:** Flags were impossible to detect.

**What to do:** Test flags with `parameters["debug"] != nil`. If you need every value of a repeated name, receive a `PathwayRequest` and read its `queryItems`; a request handler returns whether it handled the URL.

```swift
router.register(host: "example.com", path: "/search") { request in
    let isDebug = request.parameters["debug"] != nil
    let tags = request.queryItems.filter { $0.name == "tag" }.compactMap(\.value)
    print("Debug: \(isDebug), tags: \(tags)")
    return .handled
}
```

## Codable models

### Fields that are not placeholders map to query parameters

**What changed:** A model field whose coding key is not a pattern placeholder made decoding throw `notFound` and encoding throw `notEncodable`. Such fields now map to same-named query parameters: decoding reads them from the URL's query, optional ones may be absent, and encoding writes them as query items.

**Why:** Route models can carry typed query values such as a campaign or page number.

**What to do:** If a model has a field that must not appear in URLs, leave it out of `CodingKeys` and give it a default value. Code that expected these models to fail now receives values.

```swift
struct SearchRoute: Pathway {
    static let pattern = "/search/:category"

    let category: String
    let page: Int
    let campaign: String?
}

let path = try PathwayEncoder.shared.encode(SearchRoute(category: "books", page: 2, campaign: nil))
// /search/books?page=2
```

### Errors identify the failing key and value

**What changed:** `PathwayError.notDecodable` and `.notEncodable` now carry `key` and `value`, and `.notFound` carries `key`, naming the placeholder or query parameter and the offending value. Every error has a readable `description`. Raw-value enums and UUIDs that fail to decode now throw `PathwayError.notDecodable` instead of a `DecodingError`.

**Why:** Debugging a broken deep link meant guessing which placeholder was wrong.

**What to do:** Patterns that name only the kind, such as `catch PathwayError.notDecodable` or `case .notFound:`, keep working. Replace equality checks against bare cases with a pattern match or the full value, and catch `PathwayError` where you caught `DecodingError` for enum or UUID values.

```swift
// 1.1.2
if error as? PathwayError == .notFound {
    showMissingValue()
}

// 2.0
if case .notFound(let key) = error as? PathwayError {
    showMissingValue(named: key)
}
```

### Nested models are rejected when decoding

**What changed:** The decoder handed nested models the top-level placeholders, so an `Inner.id` property was read from the route's `:id`. Decoding a nested keyed container now throws `PathwayError.unsupported`, matching the encoder.

**Why:** Silently reusing top-level values produced wrong models.

**What to do:** Flatten nested models into the route.

### Empty values and explicit nil cannot be encoded

**What changed:** Encoding an empty string produced a path such as `/names/` that the decoder rejects, and an explicit `nil` wrote the text `nil` into the path. Both now throw `PathwayError.notEncodable(key:value:)`.

**Why:** Encoding must not produce a path that does not decode back to the same model.

**What to do:** Validate values before encoding, or catch the error.

### Dates keep fractional seconds

**What changed:** Dates were encoded without fractional seconds, so they did not round-trip, and decoding rejected timestamps such as `2026-01-01T00:00:00.123Z`. Dates with sub-second precision now encode with milliseconds, whole seconds keep the short form, and decoding accepts both.

**Why:** A decoded date should equal the encoded one.

**What to do:** Update code that parses Pathways-encoded dates with a formatter that lacks fractional seconds.

## Custom `PathwaysProviding` conformances

**What changed:** The protocol's requirements changed shape, and new ones were added.

**Why:** Collapsing the registration requirements keeps new handler forms from multiplying them, and the new router features need to be reachable through the protocol.

**What to do:** Code that only calls the protocol needs no further changes. A type that implements it must adopt the 2.0 requirements:

- The eight `register` requirements are now two: one typed and one path registration, each taking an optional `host`, the `matching` policy, the `supportFragmentParams` flag, and a `PathwayHandler` (`PathwayHandler<Void>` for paths), and returning a `PathwayRegistrationID`. Protocol-extension conveniences provide every previous spelling plus the request, declining, and asynchronous handler forms.
- New requirements: `allowedSchemes`, `fallback`, the async `handle(_:)`, and `unregister(_:)`.

A conformance that wraps `PathwayRouter`, for example to log every URL, looks like this:

```swift
struct LoggingRouter: PathwaysProviding {
    private var router = PathwayRouter()

    var baseHost: String {
        get { router.baseHost }
        set { router.baseHost = newValue }
    }

    var allowedSchemes: Set<String>? {
        get { router.allowedSchemes }
        set { router.allowedSchemes = newValue }
    }

    var fallback: (@MainActor @Sendable (PathwayRequest) -> Void)? {
        get { router.fallback }
        set { router.fallback = newValue }
    }

    @discardableResult
    mutating func register<T: Pathway>(
        host: String?,
        _ type: T.Type,
        matching: PathwayMatchPolicy,
        supportFragmentParams: Bool,
        handler: PathwayHandler<T>
    ) -> PathwayRegistrationID {
        router.register(host: host, type, matching: matching, supportFragmentParams: supportFragmentParams, handler: handler)
    }

    @discardableResult
    mutating func register(
        host: String?,
        path: String,
        matching: PathwayMatchPolicy,
        supportFragmentParams: Bool,
        handler: PathwayHandler<Void>
    ) -> PathwayRegistrationID {
        router.register(host: host, path: path, matching: matching, supportFragmentParams: supportFragmentParams, handler: handler)
    }

    @MainActor func handle(_ url: URL) throws -> Bool {
        print("Routing \(url)")
        return try router.handle(url)
    }

    @MainActor func handle(_ url: URL) async throws -> Bool {
        print("Routing \(url)")
        return try await router.handle(url)
    }

    mutating func unregister(_ registration: PathwayRegistrationID) {
        router.unregister(registration)
    }

    mutating func reset() {
        router.reset()
    }

    func registeredHosts() -> [String] {
        router.registeredHosts()
    }

    func registeredPatterns() -> [String] {
        router.registeredPatterns()
    }
}
```

## New in 2.0

These additions need no migration. See the [documentation hub](/docs/pathways-swift/documentation/) and the README for details.

- Handlers can receive a `PathwayRequest` with the original URL, the parameter dictionary, and every query item in order, and return whether they handled the URL.
- Handlers can decline a URL, and a router-wide `fallback` handles URLs nothing else handles.
- Asynchronous handlers and an async `handle(_:)`.
- `unregister(_:)` removes a single registration.
- Route models can decode and encode typed query parameters.
- Custom-scheme URLs without a host can be routed.
- `onOpenURL(routingTo:onError:)` routes URLs opened in a SwiftUI view hierarchy.
