---
title: "Documentation | Pathways"
description: "Pathways documentation for typed routes and URL routing."
---

<a id="content"></a>

Documentation

# Work with deep links as Swift values.

Pathways defines flat, typed route models, converts them to and from URLs, and dispatches matching URLs to handlers.

## [Getting started](/docs/pathways-swift/documentation/getting-started/)

Install Pathways, define a route, encode it, decode it, and register a handler.

**[Typed routes](/docs/pathways-swift/documentation/#typed-routes)**

Patterns, coding keys, encoding, decoding, one-way models, and errors.

**[Routing URLs](/docs/pathways-swift/documentation/#routing-urls)**

Typed and path-only handlers, exact hosts, parameters, lifecycle, and SwiftUI integration.

## [Supported values and limits](/docs/pathways-swift/documentation/#supported-values)

Scalar values and the constraints of flat URL path data.

## [Pathways API](/docs/pathways-swift/documentation/pathways/)

The generated reference for the package's single public module.

<a id="typed-routes"></a>

Typed routes

## Patterns follow Codable keys.

Each model declares a static pattern. Literal components identify the route, while components prefixed with `:` bind to Codable keys. Use `CodingKeys` when the Swift property and URL placeholder use different names.

`Pathway` supports encoding and decoding. Use `PathwayEncodable` or `PathwayDecodable` for a one-way model.

<a id="routing-urls"></a>

Routing URLs

## Choose typed or path-only handlers.

Typed handlers validate and decode path values. Path-only handlers use prefix matching when no typed values are needed. A registration can require an exact host, and every handler receives query parameters as `[String: String]`.

`handle(_:)` returns whether a handler ran and rethrows decoding or handler errors.

<a id="supported-values"></a>

Supported values

## Keep route models flat.

Pathways supports strings, booleans, integers, floating-point values, raw-value Codable enums, UUIDs, and ISO 8601 dates. Nested keyed containers, collections, and optional path segments are not supported.

Query parameters remain separate from the typed path model. Fragment parameters are experimental and require an explicit registration option.
