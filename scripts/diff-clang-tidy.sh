#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "Usage: $0 <base_branch> <compile_commands_dir> [extensions]"
}

case "${1:-}" in
    -h|--help) usage; exit 0 ;;
esac
[ $# -ge 2 ] || { usage; exit 1; }

BASE_BRANCH="$1"
COMPILE_COMMANDS="$2"
EXTENSIONS="${3:-cpp hpp h cc cxx}"

EXT_PATTERN="\.($(echo "$EXTENSIONS" | tr ' ' '|'))$"

CHANGED_FILES=$(git diff --name-only --diff-filter=ACMR "$BASE_BRANCH" -- | grep -E "$EXT_PATTERN" || true)

if [ -z "$CHANGED_FILES" ]; then
    echo "No C++ files changed — skipping clang-tidy."
    exit 0
fi

FILE_COUNT=$(echo "$CHANGED_FILES" | wc -l)
echo "Running clang-tidy on $FILE_COUNT changed file(s)..."

ERRORS=0

while IFS= read -r file; do
    [ -f "$file" ] || continue
    echo "--- $file ---"

    OUTPUT=$(clang-tidy -p "$COMPILE_COMMANDS" "$file" 2>&1 || true)

    if [ -n "$OUTPUT" ]; then
        echo "$OUTPUT"

        echo "$OUTPUT" | grep -E '^.+:[0-9]+:[0-9]+: (warning|error):' | while IFS= read -r line; do
            ann_file=$(echo "$line" | cut -d: -f1)
            ann_line=$(echo "$line" | cut -d: -f2)
            ann_col=$(echo "$line" | cut -d: -f3)
            severity=$(echo "$line" | cut -d: -f4 | tr -d ' ')
            message=$(echo "$line" | cut -d: -f5-)

            if [ "$severity" = "error" ]; then
                echo "::error file=${ann_file},line=${ann_line},col=${ann_col}::${message}"
            else
                echo "::warning file=${ann_file},line=${ann_line},col=${ann_col}::${message}"
            fi
        done

        ERR_COUNT=$(echo "$OUTPUT" | grep -cE '^.+:[0-9]+:[0-9]+: error:' || true)
        ERRORS=$((ERRORS + ERR_COUNT))
    fi
done <<< "$CHANGED_FILES"

if [ "$ERRORS" -gt 0 ]; then
    echo ""
    echo "clang-tidy found $ERRORS error(s)."
    exit 1
fi

WARN_COUNT=$(echo "$CHANGED_FILES" | while IFS= read -r file; do
    [ -f "$file" ] || continue
    clang-tidy -p "$COMPILE_COMMANDS" "$file" 2>&1 | grep -cE '^.+:[0-9]+:[0-9]+: warning:' || true
done | awk '{s+=$1} END {print s+0}')

echo ""
echo "clang-tidy complete: $ERRORS error(s), $WARN_COUNT warning(s)."
exit 0
