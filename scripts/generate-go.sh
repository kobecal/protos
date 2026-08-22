#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

protoc_gen_go_version="1.36.11"
protoc_gen_go_grpc_version="1.5.1"
protoc_gen_grpc_gateway_version="2.29.0"
protobuf_runtime_version="1.36.11"
google_api_annotations_version="0.0.0-20241104194629-dd2ea8efbc28"
generated_go_version="1.26.0"
schemas_root="proto/kobecal"

first_schema="$(find "$schemas_root" -type f -name '*.proto' -print | awk 'NR == 1 { print; exit }')"
if [[ -z "$first_schema" ]]; then
  echo "repository has no schemas; skipping Go generation"
  exit 0
fi

actual_version="$(protoc-gen-go --version 2>/dev/null || true)"
if [[ "$actual_version" != "protoc-gen-go v${protoc_gen_go_version}" ]]; then
  echo "protoc-gen-go v${protoc_gen_go_version} is required" >&2
  exit 1
fi

actual_version="$(protoc-gen-go-grpc --version 2>/dev/null || true)"
if [[ "$actual_version" != "protoc-gen-go-grpc ${protoc_gen_go_grpc_version}" ]]; then
  echo "protoc-gen-go-grpc ${protoc_gen_go_grpc_version} is required" >&2
  exit 1
fi

actual_version="$(protoc-gen-grpc-gateway --version 2>/dev/null || true)"
expected_version_prefix="Version v${protoc_gen_grpc_gateway_version},"
if [[ "$actual_version" != "$expected_version_prefix"* ]]; then
  echo "protoc-gen-grpc-gateway v${protoc_gen_grpc_gateway_version} is required" >&2
  exit 1
fi

buf generate --template buf.gen.yaml

while IFS= read -r version_file; do
  domain_dir="${version_file%/VERSION}"
  relative_unit="${domain_dir#${schemas_root}/}"
  namespace="${relative_unit%%/*}"
  domain="${relative_unit#*/}"
  generated_dir="gen/go/${namespace}/${domain}"
  module_path="github.com/kobecal/protos/${generated_dir}"

  if [[ ! -d "$generated_dir" ]]; then
    echo "${relative_unit}: protoc-gen-go produced no module directory" >&2
    exit 1
  fi

  (
    cd "$generated_dir"
    go mod init "$module_path"
    go mod edit -go="$generated_go_version"
    go mod edit -require="google.golang.org/protobuf@v${protobuf_runtime_version}"
    go mod edit -require="google.golang.org/genproto/googleapis/api@v${google_api_annotations_version}"

    while IFS= read -r import_line; do
      [[ -n "$import_line" ]] || continue
      if [[ ! "$import_line" =~ ^kobecal/([a-z0-9_]+)/([a-z0-9_]+)/v[0-9]+/ ]]; then
        continue
      fi
      dep_namespace="${BASH_REMATCH[1]}"
      dep_domain="${BASH_REMATCH[2]}"
      if [[ "$dep_namespace" == "$namespace" && "$dep_domain" == "$domain" ]]; then
        continue
      fi

      dep_module="github.com/kobecal/protos/gen/go/${dep_namespace}/${dep_domain}"
      # Reference the sibling module at its real published version. A nested
      # `replace` to a local path is ignored by Go (replace only applies from
      # the main module) and would break `go get` for consumers, so published
      # modules must not carry one. The sibling must be tagged/released before
      # the importing domain is generated with a resolvable require.
      dep_version="$(sed -n '1p' "${ROOT}/proto/kobecal/${dep_namespace}/${dep_domain}/VERSION")"
      if [[ ! "$dep_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "${relative_unit}: sibling ${dep_namespace}/${dep_domain} has invalid VERSION ${dep_version}" >&2
        exit 1
      fi
      go mod edit -require="${dep_module}@v${dep_version}"
      echo "${relative_unit}: required ${dep_module}@v${dep_version}"
    # Scan the domain's proto imports for other kobecal packages and require
    # them at their published versions. Use find+grep (not ripgrep): the CI
    # runners do not install rg, and a missing tool in the process
    # substitution would silently skip the requirement.
    done < <(find "${ROOT}/proto/kobecal/${namespace}/${domain}" -type f -name '*.proto' -exec grep -hoE 'import "kobecal/[^"]+"' {} + | sed 's/^import "//; s/"$//' | sort -u)
  )
done < <(find "$schemas_root" -mindepth 3 -maxdepth 3 -type f -name VERSION -print | LC_ALL=C sort)

while IFS= read -r version_file; do
  domain_dir="${version_file%/VERSION}"
  relative_unit="${domain_dir#${schemas_root}/}"
  namespace="${relative_unit%%/*}"
  domain="${relative_unit#*/}"
  generated_dir="gen/go/${namespace}/${domain}"
  module_path="github.com/kobecal/protos/${generated_dir}"

  (
    cd "$generated_dir"
    go mod tidy
  )

  echo "${relative_unit}: generated ${module_path}"
done < <(find "$schemas_root" -mindepth 3 -maxdepth 3 -type f -name VERSION -print | LC_ALL=C sort)
