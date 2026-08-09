# protos

`protos` is the source-of-truth monorepo for kobecal Protobuf data and HTTP
API schemas across Infra, Platform, and Product namespaces. It uses pinned Buf
dependencies for reviewed external schemas such as Google HTTP annotations.
It replaces `proto-contracts` as the central schema repository.

The repository manages messages, enums, RPC service descriptions, and HTTP
annotations. It generates Go schema modules and OpenAPI v2 documents. gRPC
runtimes and gateway server generation remain consumer-owned concerns.

## Repository layout

```text
proto/kobecal/<namespace>/<domain>/
  VERSION
  v1/
    *.proto
```

Each `<namespace>/<domain>` pair is an independently owned and versioned schema
unit. For example:

```text
proto/kobecal/contracts/agent/VERSION
proto/kobecal/contracts/agent/v1/agent.proto
```

Cross-domain imports are allowed only when the dependency direction is
documented and reviewed by both domain owners. Shared types belong in
`proto/kobecal/contracts/common` only when their semantics are stable across
domains.

## Required checks

Install the Buf version declared in [`Makefile`](Makefile), then run:

```bash
make verify
```

Pull requests are gated by:

- `buf format --diff --exit-code`
- `buf lint`
- `buf build`
- `buf breaking --against '.git#ref=<pull-request-base-sha>'`
- repository structure validation
- domain `VERSION` policy validation
- domain CODEOWNERS policy validation
- generated Go module diff validation
- generated OpenAPI document diff validation

The breaking check compares the proposed repository state with the pull
request's base commit. Local runs default to `master`. A change to a shared
schema is therefore checked together with every schema that imports it.

## Domain releases

Every domain owns a `VERSION` file containing `MAJOR.MINOR.PATCH`. A change to
that domain's compiled descriptor must increase the version. Comment-only and
format-only changes do not require a release. A version change without a
schema change is rejected.

After a change reaches `master`, CI creates an annotated Go module tag:

```text
gen/go/<namespace>/<domain>/v<MAJOR.MINOR.PATCH>
```

Example: `gen/go/contracts/agent/v0.1.0`.

Consumers import the corresponding nested Go module:

```text
github.com/kobecal/protos/gen/go/contracts/agent
```

See [schema conventions](docs/schema-conventions.md), [versioning](docs/versioning.md),
[Go generation](docs/go-generation.md), and the
[domain template](templates/domain/README.md) before adding a domain.

## Migration from proto-contracts

This repository replaces `github.com/kobecal/proto-contracts`. The seed domains
(`contracts/agent`, `contracts/common`) were migrated with package names
renamed from `contracts.<domain>.vN` to `kobecal.contracts.<domain>.vN`.
Consumers must switch their SDK module to
`github.com/kobecal/protos/gen/go/<namespace>/<domain>` and update package
imports accordingly. The old repository is deprecated and must not receive new
schemas.

## Ownership

Repository-wide and domain-specific reviews must be routed through
`.github/CODEOWNERS`. Before enabling branch protection, replace the commented
examples with the real governance team. Branch protection must require Code
Owner approval and the `schema / verify` status check; CODEOWNERS alone does
not enforce merge permissions.
