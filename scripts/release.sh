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

manifest_pinned_version() {
  awk -F'"' '/name = "caffeine_lang"/ { for (i=1; i<=NF; i++) if ($i ~ /version = /) { print $(i+1); exit } }' "$1"
}

if [ "$PRE_CLI" = "$POST_CLI" ] && [ "$PRE_LSP" = "$POST_LSP" ]; then
  PINNED_CLI=$(manifest_pinned_version caffeine_cli/manifest.toml)
  PINNED_LSP=$(manifest_pinned_version caffeine_lsp/manifest.toml)
  if [ "$PINNED_CLI" = "$VERSION" ] && [ "$PINNED_LSP" = "$VERSION" ]; then
    echo "Manifests already pin caffeine_lang ${VERSION}; nothing to refresh."
    NEED_MANIFEST_COMMIT=0
  else
    echo "error: manifests unchanged after gleam deps update, and pinned caffeine_lang" >&2
    echo "       (cli=${PINNED_CLI:-?}, lsp=${PINNED_LSP:-?}) does not match ${VERSION}." >&2
    echo "       Did you bump caffeine_lang in gleam.toml? Is ${VERSION} published to Hex?" >&2
    exit 1
  fi
else
  NEED_MANIFEST_COMMIT=1
  echo
  echo "Manifest diff:"
  git --no-pager diff -- caffeine_cli/manifest.toml caffeine_lsp/manifest.toml
fi

echo
echo "About to:"
if [ "$NEED_MANIFEST_COMMIT" = 1 ]; then
  echo "  git add caffeine_cli/manifest.toml caffeine_lsp/manifest.toml [+ any other staged changes]"
  echo "  git commit -m \"release ${TAG}\""
fi
echo "  git tag ${TAG}"
echo
read -r -p "Proceed? [y/N] " confirm
case "$confirm" in
  y|Y|yes|YES) ;;
  *) echo "Aborted. Manifest changes left in working tree."; exit 1 ;;
esac

if [ "$NEED_MANIFEST_COMMIT" = 1 ]; then
  git add caffeine_cli/manifest.toml caffeine_lsp/manifest.toml
  git commit -m "release ${TAG}"
fi
git tag "${TAG}"

echo
echo "Tagged ${TAG}. Push with:"
echo "  git push --follow-tags"
