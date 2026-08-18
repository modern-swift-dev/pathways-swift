# Typed routes

Typed routes use Swift's `Codable` system to convert between flat values and URL path components.

## Patterns and coding keys

Each model declares a `static var pattern: String`. Literal components identify the route and components prefixed by `:` bind to Codable keys:

```swift
struct ArticleRoute: Pathway {
    static let pattern = "/authors/:authorID/articles/:articleID"

    let authorID: Int
    let articleID: UUID
}
```

For this model, `/authors/7/articles/DEADBEEF-DEAD-BEEF-DEAD-BEEFDEADBEEF` binds `7` to `authorID` and the final component to `articleID`.

Keep route models flat. Nested keyed containers and unkeyed containers are unsupported.

## Encoding

`PathwayEncoder` replaces every placeholder with its model value and percent-encodes values for use in a path:

```swift
let route = ArticleRoute(authorID: 7, articleID: articleID)
let path = try PathwayEncoder.shared.encode(route)
```

To create a URL relative to a known base URL:

```swift
let url = try PathwayEncoder.shared.encode(
    route,
    relativeTo: URL(string: "https://example.com")!
)
```

The relative form returns an optional URL because URL construction can fail.

## Decoding

`PathwayDecoder` validates the URL path against the model pattern and initializes the model from captured path components:

```swift
let route = try PathwayDecoder.shared.decode(ArticleRoute.self, from: url)
```

The decoder reads path values only. Query parameters are provided separately by routing-center handlers.

## One-way models

Use `PathwayDecodable` when a model only needs decoding, or `PathwayEncodable` when it only needs encoding. Use `Pathway` when it needs both.

```swift
struct IncomingInvite: PathwayDecodable {
    static let pattern = "/invites/:code"

    let code: String
}
```

## Errors

Encoding and decoding can throw `PathwayError`:

- `notEncodable`: the value does not provide a pathway pattern or cannot be represented.
- `notDecodable`: the requested type does not provide a pattern or a component cannot be converted.
- `invalidURL`: the URL path does not match the model pattern.
- `notFound`: a pattern placeholder or value is missing.
- `unsupported`: the Codable operation requires an unsupported container or feature.

Treat these as input or route-configuration failures and handle them at the boundary where incoming URLs are processed.
