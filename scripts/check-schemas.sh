#!/usr/bin/env bash

set -euo pipefail

first_schema="$(find proto -type f -name '*.proto' -print | awk 'NR == 1 { print; exit }')"
if [[ -z "$first_schema" ]]; then
  echo "repository has no schemas; skipping bootstrap format, lint, and build checks"
  exit 0
fi

buf format --diff --exit-code
buf lint
buf build
