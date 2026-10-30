#!/usr/bin/env bash
set -euo pipefail

ROOT="${EXEC_BIT_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
WORKFLOW="$ROOT/.github/workflows/infra-lint.yml"
SCRATCH=$(mktemp -d)
trap 'rm -rf "$SCRATCH"' EXIT

SCAN="$SCRATCH/exec-bit-scan.sh"
awk '
    /^  exec-bit:$/ { in_job = 1; next }
    in_job && /^  [a-z][a-z-]*:$/ { exit }
    in_job && /^        run: \|$/ { inrun = 1; next }
    inrun && /^          / { sub(/^          /, ""); print; next }
    inrun && /^$/ { print ""; next }
    inrun { exit }
' "$WORKFLOW" > "$SCAN"

FAILED=0

if [ -s "$SCAN" ]; then
    echo "PASS: exec-bit run block extracted from infra-lint.yml"
else
    echo "FAIL: no exec-bit run block found in infra-lint.yml"
    exit 1
fi

if grep -A3 '^      enable_exec_bit:$' "$WORKFLOW" | grep -q '^        default: true$'; then
    echo "PASS: enable_exec_bit defaults to true"
else
    echo "FAIL: enable_exec_bit does not default to true"
    FAILED=1
fi

new_repo() {
    local dir="$SCRATCH/$1"
    mkdir "$dir"
    git -C "$dir" init -q -b main
    git -C "$dir" config user.email t@t
    git -C "$dir" config user.name t
    git -C "$dir" commit -q --allow-empty -m base
    git -C "$dir" update-ref refs/remotes/origin/main HEAD
    git -C "$dir" checkout -q -b feature
    echo "$dir"
}

expect_scan() {
    local expected="$1" name="$2" dir="$3" expected_path="${4:-}"
    local summary="$dir.summary" out status=0
    rm -f "$summary"
    out=$(cd "$dir" && INPUT_BASE_REF=main GITHUB_STEP_SUMMARY="$summary" bash -e "$SCAN" 2>&1) || status=$?
    if [ "$status" -ne "$expected" ]; then
        echo "FAIL: $name (exit $status, wanted $expected)"
        echo "$out"
        FAILED=1
        return
    fi
    if [ -n "$expected_path" ] && ! grep -q "$expected_path" "$summary" 2>/dev/null; then
        echo "FAIL: $name (path $expected_path missing from step summary)"
        FAILED=1
        return
    fi
    echo "PASS: $name"
}

SHEBANG_BODY=$'#!/bin/sh\necho hi'

dir=$(new_repo added-644)
printf '%s\n' "$SHEBANG_BODY" > "$dir/tool.sh"
git -C "$dir" add tool.sh
git -C "$dir" commit -q -m add
expect_scan 1 "added shebang file at 100644 fails and names the path" "$dir" "tool.sh"

dir=$(new_repo added-755)
printf '%s\n' "$SHEBANG_BODY" > "$dir/tool.sh"
chmod +x "$dir/tool.sh"
git -C "$dir" add tool.sh
git -C "$dir" commit -q -m add
expect_scan 0 "same added shebang file at 100755 passes" "$dir"

dir=$(new_repo no-shebang-644)
echo "plain text" > "$dir/notes.txt"
git -C "$dir" add notes.txt
git -C "$dir" commit -q -m add
expect_scan 0 "non-shebang file at 100644 passes" "$dir"

dir=$(new_repo untouched-legacy)
printf '%s\n' "$SHEBANG_BODY" > "$dir/legacy.sh"
git -C "$dir" add legacy.sh
git -C "$dir" commit -q -m legacy
git -C "$dir" update-ref refs/remotes/origin/main HEAD
echo "unrelated" > "$dir/README.txt"
git -C "$dir" add README.txt
git -C "$dir" commit -q -m readme
expect_scan 0 "untouched shebang file at 100644 on base passes" "$dir"

dir=$(new_repo changed-644)
printf '%s\n' "$SHEBANG_BODY" > "$dir/legacy.sh"
git -C "$dir" add legacy.sh
git -C "$dir" commit -q -m legacy
git -C "$dir" update-ref refs/remotes/origin/main HEAD
printf '%s\necho bye\n' "$SHEBANG_BODY" > "$dir/legacy.sh"
git -C "$dir" add legacy.sh
git -C "$dir" commit -q -m edit
expect_scan 1 "changed shebang file still at 100644 fails" "$dir" "legacy.sh"

dir=$(new_repo symlink)
printf '%s\n' "$SHEBANG_BODY" > "$dir/target.sh"
chmod +x "$dir/target.sh"
ln -s target.sh "$dir/link.sh"
git -C "$dir" add target.sh link.sh
git -C "$dir" commit -q -m link
expect_scan 0 "symlink to a shebang file passes" "$dir"

exit "$FAILED"
