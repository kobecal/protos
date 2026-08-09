#!/usr/bin/env bash

set -euo pipefail

schemas_root="proto/kobecal"
openapi_dir="gen/openapi"

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required to validate generated OpenAPI documents" >&2
  exit 1
fi

swagger_count="$(find "$openapi_dir" -type f -name '*.swagger.json' -print | awk 'END { print NR }')"
if [[ "$swagger_count" -eq 0 ]]; then
  echo "missing generated OpenAPI documents under ${openapi_dir}" >&2
  exit 1
fi

while IFS= read -r swagger_file; do
  swagger_relative="${swagger_file#gen/openapi/}"
  package_path="${swagger_relative%.swagger.json}"
  proto_file="${schemas_root}/${package_path#*/}.proto"
  if [[ ! -f "$proto_file" ]]; then
    echo "cannot map ${swagger_file} to a schema file" >&2
    exit 1
  fi

  relative_path="${proto_file#${schemas_root}/}"
  IFS=/ read -r namespace domain api_version filename extra <<< "$relative_path"
  if [[ -n "${extra:-}" ]] ||
     [[ ! "$filename" =~ ^[a-z][a-z0-9_]*\.proto$ ]] ||
     [[ ! "$namespace" =~ ^[a-z][a-z0-9_]*$ ]] ||
     [[ ! "$domain" =~ ^[a-z][a-z0-9_]*$ ]]; then
    echo "invalid schema path: ${proto_file}" >&2
    exit 1
  fi

  version_file="${schemas_root}/${namespace}/${domain}/VERSION"
  domain_version="$(sed -n '1p' "$version_file")"

  jq -e --arg version "$domain_version" '
    .swagger == "2.0" and
    (.info.title | length > 0) and
    .info.version == $version
  ' "$swagger_file" >/dev/null

  echo "${namespace}/${domain}: generated OpenAPI document is valid"
done < <(find "$openapi_dir" -type f -name '*.swagger.json' -print | LC_ALL=C sort)
