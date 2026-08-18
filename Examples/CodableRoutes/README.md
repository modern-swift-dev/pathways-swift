# Codable routes example

This executable demonstrates how a flat `Pathway` value can be encoded into a URL path and decoded from a URL.

From this directory, run:

```sh
swift run
```

Expected output:

```text
Encoded path: /accounts/42/business
Decoded account: 42 (business)
```

The package uses a local dependency on the repository root so it always builds against the checked-out Pathways source.
