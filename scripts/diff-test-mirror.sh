#!/usr/bin/env bash
set -euo pipefail

BASE_BRANCH="${1:?Usage: diff-test-mirror.sh <base_branch>}"
SOURCE_ROOT="${MIRROR_SOURCE_ROOT:-src}"
TEST_ROOT="${MIRROR_TEST_ROOT:-tests}"
DEFAULT_TEST_PATTERNS="test_{name}.py {name}_test.cpp"
TEST_PATTERNS="${MIRROR_TEST_PATTERNS:-$DEFAULT_TEST_PATTERNS}"
EXEMPT_GLOBS="${MIRROR_EXEMPT_GLOBS:-*__init__.py}"

is_exempt() {
    local relative_path="$1" glob
    for glob in $EXEMPT_GLOBS; do
        # shellcheck disable=SC2053
        [[ "$relative_path" == $glob ]] && return 0
    done
    return 1
}

mirrored_test_exists() {
    local relative_dir="$1" name="$2" extension="$3" pattern test_name
    for pattern in $TEST_PATTERNS; do
        [[ "$pattern" == *".$extension" ]] || continue
        test_name="${pattern//\{name\}/$name}"
        [ -f "$TEST_ROOT/$relative_dir/$test_name" ] && return 0
    done
    return 1
}

handles_extension() {
    local extension="$1" pattern
    for pattern in $TEST_PATTERNS; do
        [[ "$pattern" == *".$extension" ]] && return 0
    done
    return 1
}

ADDED_FILES=$(git diff --name-only --diff-filter=A "$BASE_BRANCH" -- "$SOURCE_ROOT" || true)
VIOLATIONS=0

while IFS= read -r filepath; do
    [ -z "$filepath" ] && continue
    relative_path="${filepath#"$SOURCE_ROOT"/}"
    filename="${relative_path##*/}"
    extension="${filename##*.}"
    name="${filename%.*}"
    relative_dir="$(dirname "$relative_path")"
    [ "$relative_dir" = "." ] && relative_dir=""

    handles_extension "$extension" || continue
    is_exempt "$relative_path" && continue

    if ! mirrored_test_exists "$relative_dir" "$name" "$extension"; then
        echo "::error file=${filepath}::No mirrored test under ${TEST_ROOT}/${relative_dir} for ${filename}"
        VIOLATIONS=$((VIOLATIONS + 1))
    fi
done <<< "$ADDED_FILES"

echo "Test mirror check complete: $VIOLATIONS violation(s) found."
[ "$VIOLATIONS" -eq 0 ]
