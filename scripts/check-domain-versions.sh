#!/usr/bin/env bash

set -euo pipefail

base_ref="${SCHEMA_BASE_REF:-master}"
schemas_root="proto/kobecal"

# Published domains that were deliberately retired. Deleting a published
# domain is normally rejected by this policy; entries here acknowledge the
# removal as a governance decision. Remove an entry once the domain is gone
# from the base ref for good.
retired_domains="miniprogram/agent"

if [[ ! "$base_ref" =~ ^[A-Za-z0-9][A-Za-z0-9._/-]*$ ]] || [[ "$base_ref" == *".."* ]]; then
  echo "invalid base ref: $base_ref" >&2
  exit 1
fi

if ! git rev-parse --verify --quiet "${base_ref}^{commit}" >/dev/null; then
  echo "base ref does not exist: $base_ref" >&2
  exit 1
fi

changed_paths="$(git diff --name-only --diff-filter=ACDMRT "${base_ref}...HEAD" -- proto/kobecal)"

if [[ -z "$changed_paths" ]]; then
  echo "no domain schema changes"
  exit 0
fi

schema_units="$({
  while IFS= read -r path; do
    [[ "$path" == proto/kobecal/* ]] || continue
    remainder="${path#proto/kobecal/}"
    namespace="${remainder%%/*}"
    remainder="${remainder#*/}"
    domain="${remainder%%/*}"
    [[ -n "$namespace" && -n "$domain" && "$domain" != "$remainder" ]] || continue
    printf '%s/%s\n' "$namespace" "$domain"
  done <<< "$changed_paths"
} | LC_ALL=C sort -u)"

while IFS= read -r schema_unit; do
  [[ -n "$schema_unit" ]] || continue

  namespace="${schema_unit%%/*}"
  domain="${schema_unit#*/}"

  if [[ ! "$namespace" =~ ^[a-z][a-z0-9_]*$ ]] || [[ ! "$domain" =~ ^[a-z][a-z0-9_]*$ ]]; then
    echo "invalid schema unit: $schema_unit" >&2
    exit 1
  fi

  domain_dir="proto/kobecal/${namespace}/${domain}"
  version_file="${domain_dir}/VERSION"

  version_changed="$(git diff --name-only --diff-filter=ACDMRT "${base_ref}...HEAD" -- "$version_file" | awk -v expected="$version_file" '$0 == expected { print; exit }')"
  if [[ -d "$domain_dir" ]]; then
    current_proto="$(find "$domain_dir" -mindepth 2 -maxdepth 2 -type f -name '*.proto' -print | awk 'NR == 1 { print; exit }')"
  else
    current_proto=""
  fi

  if [[ -z "$current_proto" ]]; then
    # Allow a one-time namespace migration (e.g. contracts/car-parking ->
    # miniprogram/car-parking): the domain name must still exist under another
    # namespace. Genuine deletions keep failing.
    migrated_to="$(find "$schemas_root" -mindepth 2 -maxdepth 2 -type d -name "$domain" -print | LC_ALL=C sort | awk 'NR == 1 { print; exit }')"
    if [[ -n "$migrated_to" ]]; then
      echo "${schema_unit}: moved to ${migrated_to#${schemas_root}/}; migration allowed" >&2
      continue
    fi
    if grep -qxF "$schema_unit" <<< "$retired_domains"; then
      echo "${schema_unit}: retired; deletion acknowledged by governance" >&2
      continue
    fi
    echo "${schema_unit}: published schema domains cannot be deleted" >&2
    exit 1
  fi

  baseline_proto="$(git ls-tree -r --name-only "$base_ref" -- "$domain_dir" | awk '/\.proto$/ { print; exit }')"
  schema_changed="false"
  if [[ -z "$baseline_proto" ]]; then
    schema_changed="true"
  else
    current_hash="$(buf build . --path "$domain_dir" --exclude-imports --exclude-source-info -o - | git hash-object --stdin)"
    baseline_hash="$(buf build ".git#ref=${base_ref}" --path "$domain_dir" --exclude-imports --exclude-source-info -o - | git hash-object --stdin)"
    if [[ "$current_hash" != "$baseline_hash" ]]; then
      schema_changed="true"
    fi
  fi

  if [[ "$schema_changed" == "true" && -z "$version_changed" ]]; then
    echo "${schema_unit}: descriptor changed but VERSION was not updated" >&2
    exit 1
  fi

  if [[ "$schema_changed" == "false" && -n "$version_changed" ]]; then
    echo "${schema_unit}: VERSION changed without a descriptor change" >&2
    exit 1
  fi

  if [[ "$schema_changed" == "false" ]]; then
    continue
  fi

  version="$(sed -n '1p' "$version_file")"

  if old_version="$(git show "${base_ref}:${version_file}" 2>/dev/null | sed -n '1p')"; then
    if [[ ! "$old_version" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]; then
      echo "${schema_unit}: baseline VERSION is invalid" >&2
      exit 1
    fi

    IFS=. read -r old_major old_minor old_patch <<< "$old_version"
    IFS=. read -r new_major new_minor new_patch <<< "$version"

    if (( 10#$new_major < 10#$old_major )) ||
       (( 10#$new_major == 10#$old_major && 10#$new_minor < 10#$old_minor )) ||
       (( 10#$new_major == 10#$old_major && 10#$new_minor == 10#$old_minor && 10#$new_patch <= 10#$old_patch )); then
      echo "${schema_unit}: VERSION must increase from ${old_version}, got ${version}" >&2
      exit 1
    fi
  fi

  echo "${schema_unit}: version ${version} is valid"
done <<< "$schema_units"
