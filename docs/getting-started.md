# Getting started

Pathways turns URL paths into flat, strongly typed Swift values and dispatches incoming URLs to registered handlers. It supports Swift 6 and has no external package dependencies.

## Add the package

In Xcode, choose **File > Add Package Dependencies** and enter:

```text
https://github.com/modern-swift-dev/pathways-swift.git
```

For another Swift package, add Pathways to `Package.swift` using the release requirement appropriate for your project:

```swift
dependencies: [
    .package(
        url: "https://github.com/modern-swift-dev/pathways-swift.git",
        branch: "main"
    )
]
```

Then add the product to your target:

```swift
.target(
    name: "YourTarget",
    dependencies: [
        .product(name: "Pathways", package: "pathways-swift")
    ]
)
```

Import the module where it is used:

```swift
import Pathways
```

## Define a typed route

A route model adopts `Pathway` and supplies a static pattern. A placeholder starts with `:` and must match the corresponding Codable key.

```swift
import Pathways

struct ProfileRoute: Pathway {
    static let pattern = "/profiles/:userID"

    let userID: Int
}
```

For custom wire names, use `CodingKeys` in both the pattern and the model:

```swift
struct ProfileRoute: Pathway {
    static let pattern = "/profiles/:user_id"

    let userID: Int

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
    }
}
```

## Encode and decode

```swift
import Foundation
import Pathways

let path = try PathwayEncoder.shared.encode(ProfileRoute(userID: 42))
// /profiles/42

let url = URL(string: "https://example.com/profiles/42")!
let route = try PathwayDecoder.shared.decode(ProfileRoute.self, from: url)
// route.userID == 42
```

Production code should avoid force-unwrapping URLs; it is used above only to keep the snippet focused.

## Route incoming URLs

Create a routing center, register handlers, and pass URLs to `handle(_:)` on the main actor:

```swift
var router = Pathways()

router.register(host: "example.com", ProfileRoute.self) { route, query in
    print("Open profile \(route.userID)")
    print("Source: \(query["source"] ?? "unknown")")
}

let handled = try router.handle(url)
```

`handle(_:)` returns `true` after a matching handler runs and `false` when no registered host and route match. Decode or handler errors are thrown to the caller.

## Next steps

- [Typed routes](typed-routes.md)
- [Routing URLs](routing.md)
- [Supported values and limitations](limitations.md)
- [Buildable examples](../Examples/README.md)
