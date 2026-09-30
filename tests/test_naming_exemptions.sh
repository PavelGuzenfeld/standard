#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SHARED="$ROOT/scripts/naming-exemptions.sh"
WORKFLOW="$ROOT/.github/workflows/cpp-quality.yml"
CONSUMERS=("$ROOT/scripts/diff-file-naming.sh" "$ROOT/scripts/generate-baseline.sh")
ARRAYS=(BUILTIN_EXEMPT_FILES BUILTIN_EXEMPT_PATTERNS)

FAILED=0

fail() {
    echo "FAIL: $1"
    FAILED=1
}

elements_of() {
    local array_name="$1"
    eval "printf '%s\n' \"\${${array_name}[@]}\""
}

array_block_from() {
    local array_name="$1" file="$2"
    sed -n "/^[[:space:]]*${array_name}=(/,/^[[:space:]]*)/p" "$file"
}

elements_in_file() {
    local array_name="$1" file="$2"
    (
        eval "$(array_block_from "$array_name" "$file")"
        elements_of "$array_name"
    )
}

[ -f "$SHARED" ] || { echo "FAIL: $SHARED missing"; exit 1; }

for array_name in "${ARRAYS[@]}"; do
    shared_elements=$(elements_in_file "$array_name" "$SHARED")
    [ -n "$shared_elements" ] || fail "$array_name empty in shared file"

    workflow_elements=$(elements_in_file "$array_name" "$WORKFLOW")
    [ "$shared_elements" = "$workflow_elements" ] || fail "$array_name in cpp-quality.yml drifted from naming-exemptions.sh"

    for consumer in "${CONSUMERS[@]}"; do
        [ -z "$(array_block_from "$array_name" "$consumer")" ] || fail "$(basename "$consumer") defines its own $array_name"
        grep -q 'naming-exemptions.sh' "$consumer" || fail "$(basename "$consumer") does not source naming-exemptions.sh"
    done
done

[ "$FAILED" -eq 0 ] && echo "naming exemptions: one source, no drift"
exit "$FAILED"
