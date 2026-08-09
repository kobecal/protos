# Go generation and distribution

Each schema domain is published as an independent nested Go module.

For schema source:

```text
proto/kobecal/contracts/agent/v1/*.proto
```

the generated module is:

```text
gen/go/contracts/agent/
  go.mod
  go.sum
  v1/*.pb.go
```

with module path:

```text
github.com/kobecal/protos/gen/go/contracts/agent
```

The compatible Git tag is therefore:

```text
gen/go/contracts/agent/v0.1.0
```

Generated code is committed so the module exists at the tagged repository
commit. CI regenerates every domain with pinned tools and rejects a dirty
`gen/go` tree.

Tool versions:

- Buf: `1.72.0`
- `protoc-gen-go`: `1.36.11`
- `protoc-gen-openapiv2`: `2.29.0`
- generated module Go directive: `1.24.0`
- protobuf Go runtime: `1.36.11`

External Proto dependencies must be declared in `buf.yaml` and pinned in
`buf.lock`. Generated Go modules may include the corresponding approved runtime
modules when service descriptors reference external annotations.
