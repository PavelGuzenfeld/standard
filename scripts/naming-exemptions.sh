# shellcheck shell=bash disable=SC2034
BUILTIN_EXEMPT_FILES=(
    "CMakeLists.txt" "Dockerfile" "README.md" "CLAUDE.md"
    "CHANGELOG.md" "CONTRIBUTING.md" "LICENSE" "Makefile"
    "Doxyfile" "package.xml" "pyproject.toml" "setup.py"
    "setup.cfg" "Cargo.toml" "Cargo.lock"
)

BUILTIN_EXEMPT_PATTERNS=(
    '^requirements.*\.txt$'
    '^\.'
    '^__init__\.py$'
    '^__main__\.py$'
    '^__pycache__$'
    '^py\.typed$'
    '^[A-Z][A-Z_-]*\.md$'
)

SNAKE_CASE_PATTERN='^[a-z][a-z0-9_]*$'

is_exempt_filename() {
    local name="$1" exempt
    for exempt in "${BUILTIN_EXEMPT_FILES[@]}"; do
        if [ "$name" = "$exempt" ]; then
            return 0
        fi
    done
    return 1
}

is_exempt_pattern() {
    local name="$1" pattern
    for pattern in "${BUILTIN_EXEMPT_PATTERNS[@]}"; do
        if echo "$name" | grep -qE "$pattern"; then
            return 0
        fi
    done
    return 1
}

is_snake_case() {
    local name="$1" prefix stripped

    if echo "$name" | grep -qE "$SNAKE_CASE_PATTERN"; then
        return 0
    fi

    for prefix in $ALLOWED_PREFIXES; do
        if [[ "$name" == "${prefix}"* ]]; then
            stripped="${name#"$prefix"}"
            if [ -n "$stripped" ] && echo "$stripped" | grep -qE "$SNAKE_CASE_PATTERN"; then
                return 0
            fi
        fi
    done

    return 1
}
