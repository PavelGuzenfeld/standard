#!/usr/bin/env bash
set -euo pipefail

SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/scripts/diff-test-mirror.sh"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

FAILED=0

new_repo_with_added_files() {
    rm -rf "$WORK/repo"
    mkdir "$WORK/repo"
    cd "$WORK/repo"
    git init -q -b main
    git config user.email t@t
    git config user.name t
    git commit -q --allow-empty -m init
    git checkout -q -b feature
    local file
    for file in "$@"; do
        mkdir -p "$(dirname "$file")"
        echo x > "$file"
    done
    git add -- "$@"
    git commit -q -m change
}

expect_exit() {
    local expected="$1" name="$2"
    shift 2
    local actual=0
    "$@" >"$WORK/out" 2>&1 || actual=$?
    if [ "$actual" -eq "$expected" ]; then
        echo "PASS: $name"
    else
        echo "FAIL: $name (exit $actual, wanted $expected)"
        cat "$WORK/out"
        FAILED=1
    fi
}

new_repo_with_added_files src/frame/parser.py
expect_exit 1 "python module without mirrored test fails" bash "$SCRIPT" main

new_repo_with_added_files src/frame/parser.py tests/frame/test_parser.py
expect_exit 0 "python module with mirrored test passes" bash "$SCRIPT" main

new_repo_with_added_files src/a/b.cpp
expect_exit 1 "cpp module without mirrored test fails" bash "$SCRIPT" main

new_repo_with_added_files src/a/b.cpp tests/a/b_test.cpp
expect_exit 0 "cpp module with mirrored test passes" bash "$SCRIPT" main

new_repo_with_added_files src/frame/parser.py
MIRROR_EXEMPT_GLOBS="frame/*" expect_exit 0 "exempted glob passes" bash "$SCRIPT" main

new_repo_with_added_files src/frame/__init__.py
expect_exit 0 "package init is exempt by default" bash "$SCRIPT" main

new_repo_with_added_files lib/frame/parser.py
MIRROR_SOURCE_ROOT=lib MIRROR_TEST_ROOT=spec MIRROR_TEST_PATTERNS="{name}_spec.py" \
    expect_exit 1 "custom roots and pattern: missing test fails" bash "$SCRIPT" main

new_repo_with_added_files lib/frame/parser.py spec/frame/parser_spec.py
MIRROR_SOURCE_ROOT=lib MIRROR_TEST_ROOT=spec MIRROR_TEST_PATTERNS="{name}_spec.py" \
    expect_exit 0 "custom roots and pattern: mirrored test passes" bash "$SCRIPT" main

new_repo_with_added_files docs/readme.py
expect_exit 0 "file outside source root is ignored" bash "$SCRIPT" main

exit "$FAILED"
