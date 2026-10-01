#!/usr/bin/env bash
set -euo pipefail

SCRIPTS="$(cd "$(dirname "$0")/.." && pwd)/scripts"
FAILED=0

expect_usage_on_stdout_for_help() {
    local script="$1" out
    if out=$(bash "$SCRIPTS/$script" --help 2>/dev/null) && grep -q "^Usage: " <<<"$out"; then
        echo "PASS: $script --help"
    else
        echo "FAIL: $script --help"
        FAILED=1
    fi
}

expect_usage_on_stderr_for_rejected_args() {
    local label="$1" script="$2"
    shift 2
    local out err status=0 errfile
    errfile=$(mktemp)
    out=$(bash "$SCRIPTS/$script" "$@" 2>"$errfile") || status=$?
    err=$(<"$errfile")
    rm -f "$errfile"
    if [ "$status" -eq 1 ] && [ -z "$out" ] && grep -q "^Usage: " <<<"$err"; then
        echo "PASS: $script $label"
    else
        echo "FAIL: $script $label (exit $status)"
        FAILED=1
    fi
}

for script in check-dangerous-workflows.sh check-hardening.sh check-layering.sh check-repo-structure.sh \
    diff-clang-format.sh diff-clang-tidy.sh diff-cppcheck.sh diff-file-naming.sh \
    diff-gdlint.sh diff-jscpd.sh diff-test-mirror.sh diff-ts-naming.sh filter-excludes.sh; do
    expect_usage_on_stdout_for_help "$script"
done

for script in check-hardening.sh check-repo-structure.sh diff-clang-format.sh diff-clang-tidy.sh diff-cppcheck.sh \
    diff-file-naming.sh diff-gdlint.sh diff-jscpd.sh diff-test-mirror.sh diff-ts-naming.sh; do
    expect_usage_on_stderr_for_rejected_args "without arguments" "$script"
done

for script in check-dangerous-workflows.sh check-layering.sh filter-excludes.sh; do
    expect_usage_on_stderr_for_rejected_args "with unknown option" "$script" --bogus
done

for script in check-dangerous-workflows.sh check-layering.sh; do
    expect_usage_on_stderr_for_rejected_args "with extra argument" "$script" one two
done
expect_usage_on_stderr_for_rejected_args "with extra argument" filter-excludes.sh one two three

exit "$FAILED"
