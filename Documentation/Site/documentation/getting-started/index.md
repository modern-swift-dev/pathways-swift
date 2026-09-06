---
title: "Getting started | Pathways"
description: "Install Pathways and define your first typed route."
---

<a id="content"></a>

Documentation

# Getting started

Pathways turns URL paths into flat, strongly typed Swift values and dispatches incoming URLs to registered handlers.

## Requirements

Use Swift 6.0 or newer. The package supports macOS 15, iOS 18, tvOS 18, watchOS 10, and visionOS 1 or newer.

## Add the package

In Xcode, choose File > Add Package Dependencies and enter `https://github.com/modern-swift-dev/pathways-swift.git`.

For another Swift package, add the current release to `Package.swift`, then add the `Pathways` product to the target that uses it.

```swift
.package(
    url: "https://github.com/modern-swift-dev/pathways-swift.git",
    from: "{{version}}"
)
```

## Define a typed route

A route model adopts `Pathway` and supplies a static pattern. A placeholder starts with `:` and must match its Codable key.

```swift
import Pathways

struct ProfileRoute: Pathway {
    static let pattern = "/profiles/:userID"

    let userID: Int
}
```

## Encode and decode the route

Encoding replaces the pattern placeholder with the model value. Decoding validates the incoming path and builds the same Swift type.

```swift
let profile = ProfileRoute(userID: 42)
let path = try PathwayEncoder.shared.encode(profile)
// /profiles/42

let url = URL(string: "https://example.com/profiles/42")!
let decoded = try PathwayDecoder.shared.decode(ProfileRoute.self, from: url)
// decoded.userID == 42
```

## Route incoming URLs

Create a routing center, register handlers, and pass URLs to `handle(_:)` on the main actor. It returns `true` after a matching handler runs and `false` when no registered host and route match.

```swift
var router = Pathways()

router.register(host: "example.com", ProfileRoute.self) { route, query in
    print("Open profile \(route.userID)")
    print("Source: \(query["source"] ?? "unknown")")
}

let handled = try router.handle(url)
```

## Compare the result

Use the boolean result to distinguish an unmatched URL from a handled one. Decode and handler failures throw, so invalid input stays separate from a URL that simply has no registration.

Continue with the [documentation hub](/docs/pathways-swift/documentation/) for coding keys, supported values, routing behavior, and API reference.
