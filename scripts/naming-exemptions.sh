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
