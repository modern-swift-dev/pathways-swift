# Contributing

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

Guides and examples live in [Documentation/Site](Documentation/Site). The [central documentation repository](https://github.com/modern-swift-dev/docs) owns the shared Astro theme, builds the guides and DocC API reference, and publishes them daily. For local builds and previews, follow the [docs README](https://github.com/modern-swift-dev/docs/blob/main/README.md).

Keep Markdown guides, example source, and Swift documentation comments in this module. Publish a GitHub release to update the version and release information on the next daily build. Commit documentation sources only.
