#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$ROOT/scripts/diff-jscpd.sh"
export JSCPD_BIN="${JSCPD_BIN:-$ROOT/tests/jscpd-tools/node_modules/.bin/jscpd}"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

FAILED=0

emit_block() {
    local kind="$1" i
    for i in $(seq 1 30); do
        case "$kind" in
            shared) echo "int shared_$i(int a) { int b = a * $i; return b + $((i * 7)); }" ;;
            add) echo "int add_$i(int x) { return x + $i; }" ;;
            clamp) echo "double clamp_$i(double x) { if (x > $i) { return $i; } return x; }" ;;
        esac
    done
}

new_repo_with_blocks() {
    rm -rf "$WORK/repo"
    mkdir "$WORK/repo"
    cd "$WORK/repo"
    git init -q -b main
    git config user.email t@t
    git config user.name t
    git commit -q --allow-empty -m init
    git checkout -q -b feature
    emit_block "$1" > first.cpp
    emit_block "$2" > second.cpp
    git add first.cpp second.cpp
    git commit -q -m change
}

expect_exit_and_output() {
    local expected_exit="$1" expected_text="$2" name="$3"
    shift 3
    local actual=0
    "$@" >"$WORK/out" 2>&1 || actual=$?
    if [ "$actual" -eq "$expected_exit" ] && grep -q "$expected_text" "$WORK/out"; then
        echo "PASS: $name"
    else
        echo "FAIL: $name (exit $actual, wanted $expected_exit, text '$expected_text')"
        cat "$WORK/out"
        FAILED=1
    fi
}

expect_no_output_text() {
    local unwanted_text="$1" name="$2"
    if grep -q "$unwanted_text" "$WORK/out"; then
        echo "FAIL: $name"
        cat "$WORK/out"
        FAILED=1
    else
        echo "PASS: $name"
    fi
}

new_repo_with_blocks shared shared
expect_exit_and_output 0 "Clone found" "duplicated 30-line block is reported without failing" \
    bash "$SCRIPT" main
expect_exit_and_output 1 "Clone found" "duplicated 30-line block fails under --strict" \
    bash "$SCRIPT" main 5 "cpp" --strict
expect_exit_and_output 0 "Clone found" "duplication under a 100 percent threshold passes --strict" \
    bash "$SCRIPT" main 100 "cpp" --strict
expect_exit_and_output 0 "No C++ files changed" "extension filter that matches nothing skips" \
    bash "$SCRIPT" main 5 "hpp" --strict

new_repo_with_blocks add clamp
expect_exit_and_output 0 "threshold 5%" "distinct files pass --strict" \
    bash "$SCRIPT" main 5 "cpp" --strict
expect_no_output_text "Clone found" "distinct files report no clones"

expect_exit_and_output 0 "^Usage: " "--help prints usage" bash "$SCRIPT" --help

exit "$FAILED"
