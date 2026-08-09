#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

protoc_gen_go_version="1.36.11"
protobuf_runtime_version="1.36.11"
google_api_annotations_version="0.0.0-20241104194629-dd2ea8efbc28"
generated_go_version="1.24.0"
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
      if [[ "$dep_namespace" == "$namespace" ]]; then
        dep_path="../${dep_domain}"
      else
        dep_path="../../${dep_namespace}/${dep_domain}"
      fi
      go mod edit -replace="${dep_module}=${dep_path}"
      echo "${relative_unit}: replaced ${dep_module} with ${dep_path}"
    done < <(rg -o 'import "kobecal/[^"]+"' --no-filename --glob '*.proto' "${ROOT}/proto/kobecal/${namespace}/${domain}" | sed 's/^import "//; s/"$//' | sort -u)
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
