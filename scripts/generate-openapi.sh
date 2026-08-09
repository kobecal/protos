#!/usr/bin/env bash

set -euo pipefail

protoc_gen_openapiv2_version="2.29.0"
schemas_root="proto/kobecal"

first_schema="$(find "$schemas_root" -type f -name '*.proto' -print | awk 'NR == 1 { print; exit }')"
if [[ -z "$first_schema" ]]; then
  echo "repository has no schemas; skipping OpenAPI generation"
  exit 0
fi

actual_version="$(protoc-gen-openapiv2 --version 2>/dev/null || true)"
expected_version_prefix="Version v${protoc_gen_openapiv2_version},"
if [[ "$actual_version" != "$expected_version_prefix"* ]]; then
  echo "protoc-gen-openapiv2 v${protoc_gen_openapiv2_version} is required" >&2
  exit 1
fi

buf generate --template buf.openapi.gen.yaml

first_openapi="$(find gen/openapi -type f -name '*.swagger.json' -print | awk 'NR == 1 { print; exit }')"
if [[ -z "$first_openapi" ]]; then
  echo "OpenAPI generation produced no Swagger documents" >&2
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
  domain_dir="${relative_path%/*/*}"
  domain_version="$(sed -n '1p' "${schemas_root}/${domain_dir}/VERSION")"

  tmp_file="$(mktemp)"
  jq --arg version "$domain_version" --arg title "$domain_dir" \
    '.info.version = $version | .info.title = $title' "$swagger_file" > "$tmp_file"
  mv "$tmp_file" "$swagger_file"

  echo "${domain_dir}: set OpenAPI version ${domain_version} for ${swagger_file}"
done < <(find gen/openapi -type f -name '*.swagger.json' -print | LC_ALL=C sort)

echo "generated OpenAPI documents under gen/openapi"
