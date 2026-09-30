#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "Usage: $0 <base_branch> [extensions]"
    echo "Environment: CLANG_FORMAT_CONFIG"
}

case "${1:-}" in
    -h|--help) usage; exit 0 ;;
esac
[ $# -ge 1 ] || { usage; exit 1; }

BASE_BRANCH="$1"
EXTENSIONS="${2:-cpp hpp h cc cxx}"
CONFIG_FILE="${CLANG_FORMAT_CONFIG:-}"

EXT_PATTERN="\.($(echo "$EXTENSIONS" | tr ' ' '|'))$"

CHANGED_FILES=$(git diff --name-only --diff-filter=ACMR "$BASE_BRANCH" -- | grep -E "$EXT_PATTERN" || true)

if [ -z "$CHANGED_FILES" ]; then
    echo "No C++ files changed — skipping clang-format."
    exit 0
fi

FILE_COUNT=$(echo "$CHANGED_FILES" | wc -l)
echo "Running clang-format on $FILE_COUNT changed file(s)..."

FORMAT_ARGS=("--dry-run" "--Werror")

if [ -n "$CONFIG_FILE" ] && [ -f "$CONFIG_FILE" ]; then
    FORMAT_ARGS+=("--style=file:$CONFIG_FILE")
fi

VIOLATIONS=0

while IFS= read -r file; do
    [ -f "$file" ] || continue

    OUTPUT=$(clang-format "${FORMAT_ARGS[@]}" "$file" 2>&1 || true)

    if [ -n "$OUTPUT" ]; then
        echo "$OUTPUT"

        echo "$OUTPUT" | grep -E '^.+:[0-9]+:[0-9]+:' | while IFS= read -r line; do
            ann_file=$(echo "$line" | cut -d: -f1)
            ann_line=$(echo "$line" | cut -d: -f2)
            ann_col=$(echo "$line" | cut -d: -f3)
            message=$(echo "$line" | cut -d: -f4-)
            echo "::error file=${ann_file},line=${ann_line},col=${ann_col}::clang-format:${message}"
        done

        VIOLATIONS=$((VIOLATIONS + 1))
    fi
done <<< "$CHANGED_FILES"

echo ""
echo "clang-format complete: $VIOLATIONS file(s) with formatting violations."

if [ "$VIOLATIONS" -gt 0 ]; then
    exit 1
fi

exit 0
