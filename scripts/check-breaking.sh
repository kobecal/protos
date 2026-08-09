#!/usr/bin/env bash

set -euo pipefail

base_ref="${SCHEMA_BASE_REF:-master}"

if [[ ! "$base_ref" =~ ^[A-Za-z0-9][A-Za-z0-9._/-]*$ ]] || [[ "$base_ref" == *".."* ]]; then
  echo "invalid base ref: $base_ref" >&2
  exit 1
fi

if ! git rev-parse --verify --quiet "${base_ref}^{commit}" >/dev/null; then
  echo "base ref does not exist: $base_ref" >&2
  exit 1
fi

baseline_proto="$(git ls-tree -r --name-only "$base_ref" -- proto | awk '/\.proto$/ { print; exit }')"
if [[ -z "$baseline_proto" ]]; then
  echo "baseline ${base_ref} has no schemas; skipping bootstrap breaking check"
  exit 0
fi

buf breaking --against ".git#ref=${base_ref}"
