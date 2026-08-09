#!/usr/bin/env bash

set -euo pipefail

schemas_root="proto/kobecal"

if [[ ! -d "$schemas_root" ]]; then
  echo "missing schema root: ${schemas_root}" >&2
  exit 1
fi

symlink="$(find proto -type l -print | awk 'NR == 1 { print; exit }')"
if [[ -n "$symlink" ]]; then
  echo "schema tree must not contain symlinks: ${symlink}" >&2
  exit 1
fi

while IFS= read -r proto_file; do
  relative_path="${proto_file#${schemas_root}/}"
  IFS=/ read -r namespace domain api_version filename extra <<< "$relative_path"

  if [[ -n "${extra:-}" ]] ||
     [[ ! "$namespace" =~ ^[a-z][a-z0-9_]*$ ]] ||
     [[ ! "$domain" =~ ^[a-z][a-z0-9_]*$ ]] ||
     [[ ! "$api_version" =~ ^v[1-9][0-9]*$ ]] ||
     [[ ! "$filename" =~ ^[a-z][a-z0-9_]*\.proto$ ]]; then
    echo "invalid schema path: ${proto_file}" >&2
    echo "expected proto/kobecal/<namespace>/<domain>/vN/<file>.proto" >&2
    exit 1
  fi

  version_file="${schemas_root}/${namespace}/${domain}/VERSION"
  if [[ ! -f "$version_file" ]]; then
    echo "${namespace}/${domain}: missing VERSION" >&2
    exit 1
  fi
done < <(find "$schemas_root" -type f -name '*.proto' -print | LC_ALL=C sort)

while IFS= read -r version_file; do
  relative_path="${version_file#${schemas_root}/}"
  IFS=/ read -r namespace domain filename extra <<< "$relative_path"

  if [[ -n "${extra:-}" ]] ||
     [[ "$filename" != "VERSION" ]] ||
     [[ ! "$namespace" =~ ^[a-z][a-z0-9_]*$ ]] ||
     [[ ! "$domain" =~ ^[a-z][a-z0-9_]*$ ]]; then
    echo "invalid VERSION path: ${version_file}" >&2
    exit 1
  fi

  line_count="$(awk 'END { print NR }' "$version_file")"
  version="$(sed -n '1p' "$version_file")"
  if [[ "$line_count" != "1" ]] ||
     [[ ! "$version" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]; then
    echo "${namespace}/${domain}: VERSION must contain one strict MAJOR.MINOR.PATCH line" >&2
    exit 1
  fi

  first_proto="$(find "${schemas_root}/${namespace}/${domain}" -mindepth 2 -maxdepth 2 -type f -name '*.proto' -print | awk 'NR == 1 { print; exit }')"
  if [[ -z "$first_proto" ]]; then
    echo "${namespace}/${domain}: VERSION exists but the domain has no schemas" >&2
    exit 1
  fi
done < <(find "$schemas_root" -type f -name VERSION -print | LC_ALL=C sort)

echo "schema repository structure is valid"
