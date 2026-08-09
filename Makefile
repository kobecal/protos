BUF_VERSION := 1.72.0

.PHONY: verify buf-version structure schema-checks breaking version-policy owner-policy openapi-check generate generated-check

verify: buf-version structure schema-checks breaking version-policy owner-policy openapi-check

buf-version:
	@test "$$(buf --version)" = "$(BUF_VERSION)" || { \
		echo "buf $(BUF_VERSION) is required" >&2; \
		exit 1; \
	}

schema-checks:
	@./scripts/check-schemas.sh

structure:
	@./scripts/check-structure.sh

breaking:
	@./scripts/check-breaking.sh

version-policy:
	@./scripts/check-domain-versions.sh

owner-policy:
	@./scripts/check-domain-owners.sh

openapi-check:
	@./scripts/check-openapi.sh

generate:
	@./scripts/generate-go.sh
	@./scripts/generate-openapi.sh

generated-check: generate
	@git diff --exit-code -- gen/go gen/openapi
