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
