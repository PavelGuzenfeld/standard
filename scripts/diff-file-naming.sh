#!/usr/bin/env bash
set -euo pipefail

BASE_BRANCH="${1:?Usage: diff-file-naming.sh <base_branch> [exceptions_file]}"
EXCEPTIONS_FILE="${2:-}"
ALLOWED_PREFIXES="${NAMING_ALLOWED_PREFIXES:-_}"

source "$(dirname "${BASH_SOURCE[0]}")/naming-exemptions.sh"

BUILTIN_EXEMPT_PATH_PATTERNS=(
    '^\.'
)

SNAKE_CASE_PATTERN='^[a-z][a-z0-9_]*$'

USER_EXCEPTIONS=()
if [ -n "$EXCEPTIONS_FILE" ] && [ -f "$EXCEPTIONS_FILE" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
        line=$(echo "$line" | xargs)
        [ -z "$line" ] && continue
        [[ "$line" == \#* ]] && continue
        USER_EXCEPTIONS+=("$line")
    done < "$EXCEPTIONS_FILE"
fi

CHANGED_FILES=$(git diff --name-only --diff-filter=ACMR "$BASE_BRANCH" -- 2>/dev/null || true)

if [ -z "$CHANGED_FILES" ]; then
    echo "No files changed — skipping file naming check."
    exit 0
fi

FILE_COUNT=$(echo "$CHANGED_FILES" | wc -l)
echo "Checking file naming conventions on $FILE_COUNT changed file(s)..."

is_exempt_filename() {
    local name="$1"
    for exempt in "${BUILTIN_EXEMPT_FILES[@]}"; do
        if [ "$name" = "$exempt" ]; then
            return 0
        fi
    done
    return 1
}

is_exempt_pattern() {
    local name="$1"
    for pattern in "${BUILTIN_EXEMPT_PATTERNS[@]}"; do
        if echo "$name" | grep -qE "$pattern"; then
            return 0
        fi
    done
    return 1
}

is_exempt_path_segment() {
    local segment="$1"
    for pattern in "${BUILTIN_EXEMPT_PATH_PATTERNS[@]}"; do
        if echo "$segment" | grep -qE "$pattern"; then
            return 0
        fi
    done
    return 1
}

is_user_exception() {
    local name="$1"
    for pattern in "${USER_EXCEPTIONS[@]}"; do
        if echo "$name" | grep -qE "$pattern"; then
            return 0
        fi
    done
    return 1
}

is_snake_case() {
    local name="$1"

    if echo "$name" | grep -qE "$SNAKE_CASE_PATTERN"; then
        return 0
    fi

    for prefix in $ALLOWED_PREFIXES; do
        if [[ "$name" == "${prefix}"* ]]; then
            local stripped="${name#$prefix}"
            if [ -n "$stripped" ] && echo "$stripped" | grep -qE "$SNAKE_CASE_PATTERN"; then
                return 0
            fi
        fi
    done

    return 1
}

VIOLATIONS=0

while IFS= read -r filepath; do
    IFS='/' read -ra SEGMENTS <<< "$filepath"
    SEGMENT_COUNT=${#SEGMENTS[@]}

    for i in "${!SEGMENTS[@]}"; do
        segment="${SEGMENTS[$i]}"
        is_last=$(( i == SEGMENT_COUNT - 1 ))

        if is_exempt_path_segment "$segment"; then
            break
        fi

        if [ "$is_last" -eq 1 ]; then
            if is_exempt_filename "$segment"; then
                continue
            fi
            if is_exempt_pattern "$segment"; then
                continue
            fi
            if [ ${#USER_EXCEPTIONS[@]} -gt 0 ] && is_user_exception "$segment"; then
                continue
            fi

            name_without_ext="${segment%.*}"
            if [ "$name_without_ext" = "$segment" ]; then
                name_without_ext="$segment"
            fi
        else
            if is_exempt_pattern "$segment"; then
                continue
            fi
            if [ ${#USER_EXCEPTIONS[@]} -gt 0 ] && is_user_exception "$segment"; then
                continue
            fi
            name_without_ext="$segment"
        fi

        if ! is_snake_case "$name_without_ext"; then
            echo "::error file=${filepath}::File naming violation: '${segment}' is not snake_case (path: ${filepath})"
            VIOLATIONS=$((VIOLATIONS + 1))
            break
        fi
    done
done <<< "$CHANGED_FILES"

echo ""
echo "File naming check complete: $VIOLATIONS violation(s) found."

if [ "$VIOLATIONS" -gt 0 ]; then
    exit 1
fi

exit 0
