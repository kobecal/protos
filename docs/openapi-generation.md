# OpenAPI generation

Public HTTP operations are defined as Protobuf RPC methods with
`google.api.http` annotations. The repository generates Swagger/OpenAPI v2
documents with the gRPC-Gateway `protoc-gen-openapiv2` plugin.

For example:

```protobuf
service AgentService {
  rpc Run(RunRequest) returns (RunResponse) {
    option (google.api.http) = {
      post: "/v1/agents/{agent_id}:run"
      body: "*"
    };
  }
}
```

Install the pinned tool versions declared by the generation scripts and run:

```bash
buf dep update
make generate
make verify
```

`jq` is required by `make verify` to validate the generated documents' version,
paths, and response references.

One document is generated per service-bearing schema file:

```text
gen/openapi/agent.swagger.json
```

The document's `info.version` must match the owning domain's `VERSION`.
Generated documents are committed and must not be edited manually.

OpenAPI-only overrides such as document metadata and required fields are
maintained per document under `openapi/` when needed. Keeping these overrides
outside `.proto` avoids adding OpenAPI generator annotations to the published
Go schema module.

The generated document describes paths, query and path parameters, and response
schemas. Consumer services remain responsible for serving the document and a
Swagger UI, and for contract tests that compare the generated document with the
actual HTTP router behavior.
