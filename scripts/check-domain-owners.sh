#!/usr/bin/env bash

set -euo pipefail

codeowners_file=".github/CODEOWNERS"
schemas_root="proto/kobecal"

if [[ ! -f "$codeowners_file" ]]; then
  echo "missing ${codeowners_file}" >&2
  exit 1
fi

while IFS= read -r version_file; do
  domain_dir="${version_file%/VERSION}"
  domain="${domain_dir##*/}"
  namespace_dir="${domain_dir%/*}"
  namespace="${namespace_dir##*/}"

  if [[ ! "$namespace" =~ ^[a-z][a-z0-9_]*$ ]] || [[ ! "$domain" =~ ^[a-z][a-z0-9_]*$ ]]; then
    echo "invalid schema unit: ${namespace}/${domain}" >&2
    exit 1
  fi

  pattern="/${domain_dir}/"
  owners="$(awk -v pattern="$pattern" '
    $1 == pattern {
      for (field = 2; field <= NF; field++) {
        print $field
      }
    }
  ' "$codeowners_file")"

  if [[ -z "$owners" ]]; then
    echo "${namespace}/${domain}: missing exact CODEOWNERS rule ${pattern}" >&2
    exit 1
  fi

  while IFS= read -r owner; do
    if [[ ! "$owner" =~ ^@[A-Za-z0-9][A-Za-z0-9_.-]*(/[A-Za-z0-9][A-Za-z0-9_.-]*)?$ ]]; then
      echo "${namespace}/${domain}: invalid CODEOWNER ${owner}" >&2
      exit 1
    fi
  done <<< "$owners"

  echo "${namespace}/${domain}: CODEOWNERS rule is valid"
done < <(find "$schemas_root" -mindepth 3 -maxdepth 3 -type f -name VERSION -print | LC_ALL=C sort)
