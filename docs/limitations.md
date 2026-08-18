# Supported values and limitations

Pathways intentionally models URL paths as flat data.

## Supported values

The encoder and decoder support these scalar values through Swift's Codable implementations:

- `String` and `Bool`
- Signed and unsigned integer types
- `Float` and `Double`
- Raw-value Codable enums
- `UUID`
- `Date` using an ISO 8601 internet date-time with a time zone and no fractional seconds

Values are encoded as URL path components. Encoded strings are percent-escaped using `urlPathAllowed`.

## Current limitations

- Route models must be flat; nested keyed and unkeyed containers are unsupported.
- Optional path values are not a supported way to make a segment optional. Model separate URL shapes as separate routes.
- The pattern syntax has literal components and `:placeholder` components only.
- Query parameters are not part of typed model decoding. Routing handlers receive them as `[String: String]`.
- Duplicate query names collapse to one dictionary value.
- Typed route matching is based on the model's path pattern; URL schemes are not constrained by registration.
- Host matching is exact and case-sensitive at the string-comparison layer.
- Fragment parameter handling is experimental and must be enabled per handler.

## Pattern design guidance

Prefer explicit, non-overlapping patterns:

```text
/users/:userID
/articles/:articleID
/settings
```

Give placeholders the same spelling as their Codable keys. When Swift property names and URL names differ, define `CodingKeys` explicitly. Keep query data out of the route model and read it from the handler's parameter dictionary.
