#!/usr/bin/env bash
set -euo pipefail

BASE_BRANCH="${1:?Usage: diff-ts-naming.sh <base_branch> [extensions]}"
EXTENSIONS="${2:-ts tsx}"
CONFIG_FILE="${TS_NAMING_CONFIG:-eslint-naming.config.mjs}"

EXT_PATTERN="\.($(echo "$EXTENSIONS" | tr ' ' '|'))$"

CHANGED_FILES=$(git diff --name-only --diff-filter=ACMR "$BASE_BRANCH" -- | grep -E "$EXT_PATTERN" || true)

if [ -z "$CHANGED_FILES" ]; then
    echo "No TypeScript files changed — skipping ts-naming."
    exit 0
fi

FILE_COUNT=$(echo "$CHANGED_FILES" | wc -l)
echo "Running ts-naming on $FILE_COUNT changed file(s)..."

mapfile -t FILES <<< "$CHANGED_FILES"

if npx --no-install eslint --no-config-lookup --config "$CONFIG_FILE" "${FILES[@]}"; then
    echo "ts-naming: all changed files pass."
else
    echo "::error::ts-naming: naming violations found in changed files."
    exit 1
fi
