#!/usr/bin/env bash
set -euo pipefail

SCRIPTS="$(cd "$(dirname "$0")/.." && pwd)/scripts"
FAILED=0

expect_usage_on_help() {
    local script="$1" out
    if out=$(bash "$SCRIPTS/$script" --help 2>&1) && grep -q "^Usage: " <<<"$out"; then
        echo "PASS: $script --help"
    else
        echo "FAIL: $script --help"
        FAILED=1
    fi
}

expect_usage_on_missing_args() {
    local script="$1" out status=0
    out=$(bash "$SCRIPTS/$script" 2>&1) || status=$?
    if [ "$status" -eq 1 ] && grep -q "^Usage: " <<<"$out"; then
        echo "PASS: $script without arguments"
    else
        echo "FAIL: $script without arguments (exit $status)"
        FAILED=1
    fi
}

for script in check-dangerous-workflows.sh check-layering.sh check-repo-structure.sh \
    diff-clang-format.sh diff-clang-tidy.sh diff-cppcheck.sh diff-file-naming.sh \
    diff-gdlint.sh diff-test-mirror.sh diff-ts-naming.sh filter-excludes.sh; do
    expect_usage_on_help "$script"
done

for script in check-repo-structure.sh diff-clang-format.sh diff-clang-tidy.sh diff-cppcheck.sh \
    diff-file-naming.sh diff-gdlint.sh diff-test-mirror.sh diff-ts-naming.sh; do
    expect_usage_on_missing_args "$script"
done

exit "$FAILED"
