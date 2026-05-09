#!/usr/bin/env bash
set -euo pipefail

# Refresh manifest.toml outer_checksum for caffeine_lang in both packages,
# then commit and tag. Assumes you've already bumped versions in code
# (gleam.toml, package.json, etc.) and that the new caffeine_lang version
# is published to Hex.
#
# Usage: scripts/release.sh

cd "$(git rev-parse --show-toplevel)"

VERSION=$(awk -F'"' '/^version = /{print $2; exit}' caffeine_cli/gleam.toml)
if [ -z "${VERSION:-}" ]; then
  echo "error: could not read version from caffeine_cli/gleam.toml" >&2
  exit 1
fi

TAG="v${VERSION}"

if git rev-parse "${TAG}" >/dev/null 2>&1; then
  echo "error: tag ${TAG} already exists" >&2
  exit 1
fi

# Capture pre-state so we can detect whether manifests actually changed.
PRE_CLI=$(sha256sum caffeine_cli/manifest.toml | cut -d' ' -f1)
PRE_LSP=$(sha256sum caffeine_lsp/manifest.toml | cut -d' ' -f1)

echo "Refreshing caffeine_lang in caffeine_cli/manifest.toml..."
(cd caffeine_cli && gleam deps update caffeine_lang)

echo "Refreshing caffeine_lang in caffeine_lsp/manifest.toml..."
(cd caffeine_lsp && gleam deps update caffeine_lang)

POST_CLI=$(sha256sum caffeine_cli/manifest.toml | cut -d' ' -f1)
POST_LSP=$(sha256sum caffeine_lsp/manifest.toml | cut -d' ' -f1)

if [ "$PRE_CLI" = "$POST_CLI" ] && [ "$PRE_LSP" = "$POST_LSP" ]; then
  echo "error: manifests unchanged after gleam deps update." >&2
  echo "       Did you bump caffeine_lang in gleam.toml? Is ${VERSION} published to Hex?" >&2
  exit 1
fi

echo
echo "Manifest diff:"
git --no-pager diff -- caffeine_cli/manifest.toml caffeine_lsp/manifest.toml

echo
echo "About to:"
echo "  git add caffeine_cli/manifest.toml caffeine_lsp/manifest.toml [+ any other staged changes]"
echo "  git commit -m \"release ${TAG}\""
echo "  git tag ${TAG}"
echo
read -r -p "Proceed? [y/N] " confirm
case "$confirm" in
  y|Y|yes|YES) ;;
  *) echo "Aborted. Manifest changes left in working tree."; exit 1 ;;
esac

git add caffeine_cli/manifest.toml caffeine_lsp/manifest.toml
git commit -m "release ${TAG}"
git tag "${TAG}"

echo
echo "Tagged ${TAG}. Push with:"
echo "  git push --follow-tags"
