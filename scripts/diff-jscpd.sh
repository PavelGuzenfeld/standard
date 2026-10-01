#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "Usage: $0 <base_branch> [threshold_percent] [extensions] [--strict]"
    echo "Environment: JSCPD_BIN"
}

STRICT=false
ARGS=()
for arg in "$@"; do
    case "$arg" in
        -h|--help) usage; exit 0 ;;
        --strict) STRICT=true ;;
        *) ARGS+=("$arg") ;;
    esac
done
[ ${#ARGS[@]} -ge 1 ] || { usage >&2; exit 1; }

BASE_BRANCH="${ARGS[0]}"
THRESHOLD="${ARGS[1]:-5}"
EXTENSIONS="${ARGS[2]:-cpp hpp h cc cxx}"
JSCPD_BIN="${JSCPD_BIN:-jscpd}"

EXT_PATTERN="\.($(echo "$EXTENSIONS" | tr ' ' '|'))$"

mapfile -t CHANGED_FILES < <(git diff --name-only --diff-filter=ACMR "$BASE_BRANCH" -- | grep -E "$EXT_PATTERN" || true)

if [ ${#CHANGED_FILES[@]} -eq 0 ]; then
    echo "No C++ files changed — skipping jscpd."
    exit 0
fi

echo "Running jscpd on ${#CHANGED_FILES[@]} changed file(s), threshold ${THRESHOLD}%..."

STATUS=0
"$JSCPD_BIN" --threshold "$THRESHOLD" --reporters console "${CHANGED_FILES[@]}" || STATUS=$?

if [ "$STATUS" -ne 0 ]; then
    echo "::warning::jscpd: duplication over ${THRESHOLD}% in changed files"
    if [ "$STRICT" = true ]; then
        exit 1
    fi
fi

exit 0
