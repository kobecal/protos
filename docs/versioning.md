# Domain versioning

## VERSION file

Every schema domain has
`proto/kobecal/<namespace>/<domain>/VERSION` containing exactly one semantic
version without a leading `v`:

```text
1.2.0
```

The version is the release version of that domain's schema, not the Protobuf
package version. Package `v1` can therefore have domain releases `1.0.0`,
`1.1.0`, and `1.2.0`.

## Required bump

- Patch: compatible correction that changes no generated API surface.
- Minor: additive compatible schema change.
- Major: a new intentionally incompatible schema generation. Breaking changes
  remain blocked in an existing package; normally introduce package `v2`.

A compiled descriptor change requires a monotonically increasing domain
version. Source comments and formatting are excluded from this comparison. A
version-only change is rejected so unrelated domains do not receive release
tags.

## Tags

Merges to `master` create annotated Go module tags in this format:

```text
gen/go/<namespace>/<domain>/v<version>
```

Each domain is published as an independent nested Go module at
`gen/go/<namespace>/<domain>`. The tag prefix must match that module's
repository subdirectory so the Go toolchain can resolve the version.

## Bootstrap

The first schema change for a new domain should use `0.1.0` while the contract
is experimental or `1.0.0` when consumers may rely on compatibility guarantees.
