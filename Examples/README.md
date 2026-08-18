# Examples

Each example is an independent Swift package that depends on the repository root. This keeps the examples buildable without adding executable products to the Pathways library package.

## CodableRoutes

Demonstrates defining a `Pathway` model, encoding it into a path, and decoding it from a URL.

```sh
cd Examples/CodableRoutes
swift run
```

## RoutingCenter

Demonstrates typed and path-only registration, exact host filtering, query parameters, and the boolean result from `handle(_:)`.

```sh
cd Examples/RoutingCenter
swift run
```

See each example's README and source for the complete code.
