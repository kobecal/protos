# kobecal schema namespaces

Schemas use a two-level ownership boundary:

```text
<namespace>/<domain>/
  VERSION
  v1/*.proto
```

For example, shared contracts live under `miniprogram/<domain>`, while future
infra, platform, or product schemas may use `infra/<domain>`,
`platform/<domain>`, or `product/<domain>`.

Namespace and domain directory names must match `[a-z][a-z0-9_]*`. Copy the
files under `templates/domain` when introducing a domain.

Do not create a shared type in `common` solely because two messages currently
have similar fields. A common domain should only be introduced when types have
the same meaning, lifecycle, and ownership for every consumer.
