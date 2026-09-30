#!/usr/bin/env bash
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECK="$REPO_ROOT/scripts/check-repo-structure.sh"
FAILURES=0

declare -A FIXTURES=(
    [python]="src/mypkg/__init__.py tests/test_mypkg.py pyproject.toml README.md"
    [cmake-cpp]="include/mylib/mylib.hpp src/mylib.cpp tests/test_mylib.cpp CMakeLists.txt README.md"
    [typescript]="src/index.ts tests/index.test.ts package.json tsconfig.json README.md"
    [godot]="project.godot scenes/main.tscn scripts/main.gd README.md"
)

make_fixture() {
    local root="$1" entries="$2" entry
    for entry in $entries; do
        mkdir -p "$root/$(dirname "$entry")"
        : > "$root/$entry"
    done
}

required_files() {
    sed -n 's/^file:\(.*\)$/\1/p' "$1"
}

required_dirs() {
    sed -n 's/^dir:\(.*\)$/\1/p' "$1"
}

check_failed() {
    echo "  FAIL: $1"
    FAILURES=$((FAILURES + 1))
}

for kind in "${!FIXTURES[@]}"; do
    template="$REPO_ROOT/configs/repo-structure-$kind.txt"
    echo "=== $kind ==="
    root="$(mktemp -d)"
    make_fixture "$root" "${FIXTURES[$kind]}"

    if [ ! -f "$template" ]; then
        check_failed "template missing: $template"
        rm -rf "$root"
        continue
    fi

    if "$CHECK" "$template" "$root" > /dev/null; then
        echo "  PASS: minimal fixture passes"
    else
        check_failed "minimal fixture rejected"
    fi

    for file in $(required_files "$template"); do
        out="$(mv "$root/$file" "$root/$file.bak" && "$CHECK" "$template" "$root" 2>&1)"
        status=$?
        mv "$root/$file.bak" "$root/$file"
        if [ "$status" -ne 0 ] && grep -qF "Required file missing: $file" <<< "$out"; then
            echo "  PASS: removing $file fails and names it"
        else
            check_failed "removing $file did not fail naming it"
        fi
    done

    for dir in $(required_dirs "$template"); do
        trimmed="${dir%/}"
        mv "$root/$trimmed" "$root/$trimmed.bak"
        out="$("$CHECK" "$template" "$root" 2>&1)"
        status=$?
        mv "$root/$trimmed.bak" "$root/$trimmed"
        if [ "$status" -ne 0 ] && grep -qF "Required directory missing: $dir" <<< "$out"; then
            echo "  PASS: removing $dir fails and names it"
        else
            check_failed "removing $dir did not fail naming it"
        fi
    done
    rm -rf "$root"
done

[ "$FAILURES" -eq 0 ]
