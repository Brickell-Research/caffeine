.PHONY: lint lint-fix test test-js test-e2e test-all build ci dev-link dev-unlink

# Path to local caffeine_lang checkout, relative to caffeine_cli/ and caffeine_lsp/ dirs.
# Default assumes caffeine_lang repo is a sibling: ../caffeine_lang (from repo root).
CAFFEINE_LANG_PATH ?= ../../caffeine_lang

# Check code formatting
lint:
	cd caffeine_cli && gleam format --check
	cd caffeine_lsp && gleam format --check

# Fix code formatting
lint-fix:
	cd caffeine_cli && gleam format
	cd caffeine_lsp && gleam format

# Build all packages
build:
	cd caffeine_cli && gleam build
	cd caffeine_lsp && gleam build

# Run tests (Erlang target)
test:
	cd caffeine_cli && gleam test
	cd caffeine_lsp && gleam test

# Run tests (JavaScript target)
test-js:
	cd caffeine_cli && gleam test --target=javascript
	cd caffeine_lsp && gleam test --target=javascript

# Run LSP end-to-end tests
test-e2e:
	cd caffeine_lsp && gleam build --target javascript
	bun test test/lsp_e2e/

test-all: test test-js test-e2e

# CI pipeline
ci: lint build test

# Switch caffeine_lang dependency to local path for development.
# Usage: make dev-link
#        make dev-link CAFFEINE_LANG_PATH=/path/to/caffeine_lang
dev-link:
	@echo "Linking caffeine_lang from $(CAFFEINE_LANG_PATH)..."
	cd caffeine_cli && sed -i '' 's|caffeine_lang = .*|caffeine_lang = { path = "$(CAFFEINE_LANG_PATH)" }|' gleam.toml
	cd caffeine_lsp && sed -i '' 's|caffeine_lang = .*|caffeine_lang = { path = "$(CAFFEINE_LANG_PATH)" }|' gleam.toml
	@echo "Linked. Remember to run 'make dev-unlink' before committing."

# Restore caffeine_lang dependency to Hex for CI/release.
dev-unlink:
	@echo "Restoring caffeine_lang to Hex dependency..."
	cd caffeine_cli && sed -i '' 's|caffeine_lang = .*|caffeine_lang = ">= 5.0.12 and < 6.0.0"|' gleam.toml
	cd caffeine_lsp && sed -i '' 's|caffeine_lang = .*|caffeine_lang = ">= 5.0.12 and < 6.0.0"|' gleam.toml
	@echo "Restored. Safe to commit."
