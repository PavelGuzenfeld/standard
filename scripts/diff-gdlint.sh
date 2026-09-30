#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "Usage: $0 <base_branch> [config_file]"
}

case "${1:-}" in
    -h|--help) usage; exit 0 ;;
esac
[ $# -ge 1 ] || { usage >&2; exit 1; }

BASE_BRANCH="$1"
CONFIG_FILE="${2:-$(cd "$(dirname "$0")/.." && pwd)/configs/gdlintrc}"
REPO_ROOT="$(git rev-parse --show-toplevel)"

CHANGED_FILES=$(git diff --name-only --diff-filter=ACMR "$BASE_BRANCH" -- | grep -E '\.gd$' || true)

if [ -z "$CHANGED_FILES" ]; then
    echo "No GDScript files changed — skipping gdlint."
    exit 0
fi

LINT_DIR=$(mktemp -d)
trap 'rm -rf "$LINT_DIR"' EXIT
cp "$CONFIG_FILE" "$LINT_DIR/gdlintrc"

VIOLATIONS=0
while IFS= read -r file; do
    [ -f "$REPO_ROOT/$file" ] || continue
    OUTPUT=$(cd "$LINT_DIR" && gdlint "$REPO_ROOT/$file" 2>&1) && continue
    VIOLATIONS=$((VIOLATIONS + 1))
    echo "$OUTPUT" | grep -E ': Error: ' | while IFS= read -r line; do
        rel="${line#"$REPO_ROOT"/}"
        ann_line=$(echo "$rel" | cut -d: -f2)
        message=$(echo "$rel" | cut -d: -f4-)
        echo "::error file=${file},line=${ann_line}::gdlint:${message}"
    done
done <<< "$CHANGED_FILES"

echo "gdlint: $VIOLATIONS file(s) with naming violations"
[ "$VIOLATIONS" -eq 0 ]
