#!/usr/bin/env bash

set -euo pipefail

if [[ "$#" -ne 2 ]]; then
  echo "usage: $0 <before-sha> <after-sha>" >&2
  exit 1
fi

before_sha="$1"
after_sha="$2"

if [[ ! "$before_sha" =~ ^[0-9a-f]{40}$ ]] || [[ ! "$after_sha" =~ ^[0-9a-f]{40}$ ]]; then
  echo "before and after revisions must be full lowercase commit SHAs" >&2
  exit 1
fi

zero_sha="0000000000000000000000000000000000000000"
if [[ "$before_sha" == "$zero_sha" ]]; then
  diff_range="$after_sha"
else
  diff_range="${before_sha}..${after_sha}"
fi

changed_versions="$(git diff --name-only --diff-filter=ACDMRT "$diff_range" -- 'proto/kobecal/*/*/VERSION')"

if [[ -z "$changed_versions" ]]; then
  echo "no domain VERSION changes"
  exit 0
fi

while IFS= read -r version_file; do
  [[ -n "$version_file" ]] || continue

  if [[ ! "$version_file" =~ ^proto/kobecal/([a-z][a-z0-9_]*)/([a-z][a-z0-9_]*)/VERSION$ ]]; then
    echo "invalid VERSION path: $version_file" >&2
    exit 1
  fi

  namespace="${BASH_REMATCH[1]}"
  domain="${BASH_REMATCH[2]}"
  schema_unit="${namespace}/${domain}"
  version="$(git show "${after_sha}:${version_file}" | tr -d '\r\n')"

  if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "${schema_unit}: invalid VERSION ${version}" >&2
    exit 1
  fi

  tag="gen/go/${schema_unit}/v${version}"
  module_file="gen/go/${schema_unit}/go.mod"
  expected_module="module github.com/kobecal/protos/gen/go/${schema_unit}"
  actual_module="$(git show "${after_sha}:${module_file}" 2>/dev/null | sed -n '1p' || true)"
  if [[ "$actual_module" != "$expected_module" ]]; then
    echo "${schema_unit}: missing generated Go module ${module_file}" >&2
    exit 1
  fi
  if existing_commit="$(git rev-list -n 1 "$tag" 2>/dev/null)"; then
    if [[ "$existing_commit" != "$after_sha" ]]; then
      echo "tag ${tag} already points to ${existing_commit}" >&2
      exit 1
    fi
    echo "tag ${tag} already exists"
    continue
  fi

  git tag -a "$tag" "$after_sha" -m "${schema_unit} schema ${version}"
  git push origin "refs/tags/${tag}"
  echo "created ${tag}"
done <<< "$changed_versions"
