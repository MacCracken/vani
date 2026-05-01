#!/usr/bin/env bash
# version-bump.sh — bump vani's VERSION and prep CHANGELOG header.
#
# Usage:  ./scripts/version-bump.sh X.Y.Z
#
# What this does:
#   1. Writes X.Y.Z to VERSION (cyrius.cyml's `version = "${file:VERSION}"` picks it up automatically).
#   2. Renames the `## [Unreleased]` heading in CHANGELOG.md to `## [X.Y.Z] — YYYY-MM-DD` and re-inserts an empty `## [Unreleased]` above it.
#
# What this does NOT do:
#   - Commit. The user handles all git operations.
#   - Tag. Tag after the commit lands.
#   - Push. Pushing the tag fires .github/workflows/release.yml.
#
# After running:
#   - Review the diff (git diff VERSION CHANGELOG.md).
#   - cyrius distlib  (regenerates dist/vani.cyr with the new version line in the header).
#   - Commit + tag + push when ready.

set -euo pipefail

if [ $# -ne 1 ]; then
    echo "Usage: $0 <X.Y.Z>" >&2
    exit 1
fi

NEW="$1"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Validate semver shape
if ! echo "$NEW" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
    echo "error: '$NEW' is not semver X.Y.Z" >&2
    exit 1
fi

OLD="$(tr -d '[:space:]' < "$ROOT/VERSION")"
if [ "$OLD" = "$NEW" ]; then
    echo "VERSION already $NEW — nothing to do" >&2
    exit 0
fi

DATE="$(date -u +%Y-%m-%d)"
echo "$NEW" > "$ROOT/VERSION"
echo "VERSION: $OLD → $NEW"

# CHANGELOG: rename `## [Unreleased]` → `## [X.Y.Z] — YYYY-MM-DD` and
# re-insert an empty `## [Unreleased]` above it. Emits a parse error
# if `## [Unreleased]` isn't found — that means the previous release
# already rolled it forward and this script is being run in the wrong
# order.
if ! grep -q '^## \[Unreleased\]' "$ROOT/CHANGELOG.md"; then
    echo "error: CHANGELOG.md has no '## [Unreleased]' heading — refusing to bump" >&2
    exit 1
fi

# em-dash: U+2014. Match the existing convention.
sed -i "0,/^## \[Unreleased\]/ s||## [Unreleased]\n\n## [$NEW] — $DATE|" "$ROOT/CHANGELOG.md"

echo "CHANGELOG.md: '## [Unreleased]' → '## [$NEW] — $DATE' (with new empty Unreleased above)"
echo
echo "Next:"
echo "  cd $ROOT"
echo "  cyrius distlib                 # regenerate dist/vani.cyr"
echo "  git diff VERSION CHANGELOG.md dist/vani.cyr"
echo "  git add -A && git commit -m 'release $NEW'"
echo "  git tag $NEW && git push --tags"
