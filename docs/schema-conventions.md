# Schema conventions

## Scope

This repository defines Protobuf messages, enums, RPC service descriptions, and
HTTP annotations used to generate shared Go contracts and OpenAPI documents.
Runtime server implementations and gateway wiring remain in consumer services.

External Proto dependencies must be declared in `buf.yaml`, pinned by
`buf.lock`, and reviewed for ownership, provenance, and compatibility. The
Google APIs module is approved for `google.api.http` annotations.

## Packages and files

- Source path: `proto/kobecal/<namespace>/<domain>/<api-version>/*.proto`.
- Package: `kobecal.<namespace>.<domain>.<api-version>`.
- API versions use `v1`, `v2`, and so on.
- A file must belong to exactly one namespace and domain.
- Storage, database, and ORM models are not API schemas.
- Public HTTP endpoints must declare an RPC method and `google.api.http` rule.
- HTTP paths in annotations must match the deployed public API contract.

Example:

```protobuf
syntax = "proto3";

package kobecal.miniprogram.agent.v1;

option go_package = "github.com/kobecal/protos/gen/go/miniprogram/agent/v1;agentv1";
```

## Compatibility

- Never reuse a field number.
- Reserve removed field numbers and names.
- Prefer additive changes within a versioned package.
- Introduce a new package version for an intentional breaking change.
- Every enum must define an `*_UNSPECIFIED = 0` value.
- Preserve published field names when JSON compatibility matters.
- Document units in field names when a well-known type is not used, for
  example `duration_ns`.

Buf breaking checks protect Protobuf schema compatibility. They do not protect
HTTP paths, status codes, defaults, authorization behavior, or other runtime
semantics; consumers must keep separate contract tests for those dimensions.

## HTTP and OpenAPI

- RPC services describe API operations; they do not require consumers to run a
  gRPC server or generated gateway.
- Request messages define path and query parameters used by HTTP annotations.
- Response messages must describe the complete externally visible HTTP body,
  including any service-wide response envelope.
- Generated OpenAPI documents are committed under `gen/openapi` and must not be
  edited manually.
- Authentication, deployment-specific server URLs, and runtime middleware must
  be documented explicitly when they are part of the public contract.

## Cross-domain imports

- Imports must point from a consumer domain to a stable provider domain.
- Both owners must approve a new cross-domain dependency.
- Cyclic domain imports are prohibited.
- Changes to a provider must consider all reverse dependencies.
- Do not introduce a `common` domain until a concrete shared ownership and
  lifecycle requirement exists.

## Dynamic values

Do not default every dynamic payload to `google.protobuf.Struct`. Before adding
one, decide whether the value should instead use a typed message, an enum, or a
`oneof`. Opaque values must document their supported JSON shapes and limits.
