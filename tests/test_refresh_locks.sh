#!/usr/bin/env bash
set -euo pipefail

SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/scripts/refresh-locks.sh"
FAILED=0

expect_contains() {
    local label="$1" haystack="$2" needle="$3"
    if grep -qF -- "$needle" <<<"$haystack"; then
        echo "PASS: $label"
    else
        echo "FAIL: $label (missing: $needle)"
        FAILED=1
    fi
}

help_output=$(bash "$SCRIPT" --help)
expect_contains "--help prints usage" "$help_output" "Usage: "
expect_contains "--help names --list" "$help_output" "--list"

targets=$(bash "$SCRIPT" --list)
for name in docs layering patterns; do
    expect_contains "lists $name compile target" "$targets" "compile .github/requirements/$name.in -> .github/requirements/$name.txt"
done
expect_contains "lists flawfinder heredoc" "$targets" "inline  .github/workflows/cpp-quality.yml: flawfinder"
expect_contains "lists diff-cover heredoc" "$targets" "inline  .github/workflows/cpp-quality.yml: diff-cover"
expect_contains "lists cmakelang heredoc" "$targets" "inline  .github/workflows/infra-lint.yml: cmakelang"

status=0
bash "$SCRIPT" --bogus >/dev/null 2>&1 || status=$?
if [ "$status" -eq 1 ]; then echo "PASS: rejects unknown option"; else echo "FAIL: rejects unknown option"; FAILED=1; fi

exit "$FAILED"
