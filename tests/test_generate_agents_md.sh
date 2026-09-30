#!/usr/bin/env bash
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
GENERATOR="$HERE/../scripts/generate-agents-md.sh"
TEMPLATE="$HERE/../configs/AGENTS.md"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

headings() {
    awk '/^```/ { fenced = !fenced; next } !fenced && /^#{1,4} / { print }' "$1" | sort -u
}

(cd "$WORK" && touch CMakeLists.txt pyproject.toml && yes y | bash "$GENERATOR" --output "$WORK/AGENTS.md" >/dev/null 2>&1)

FAILURES=0

extra="$(comm -23 <(headings "$WORK/AGENTS.md") <(headings "$TEMPLATE"))"
if [ -n "$extra" ]; then
    FAILURES=$((FAILURES + 1)); echo "  FAIL: generated sections missing from template:"; echo "$extra" | sed 's/^/    /'
else
    echo "  PASS: every generated section exists in the template"
fi

if grep -q 'SDLC' "$WORK/AGENTS.md"; then
    FAILURES=$((FAILURES + 1)); echo "  FAIL: generated file still mentions SDLC"
else
    echo "  PASS: generated file does not mention SDLC"
fi

[ "$FAILURES" -eq 0 ]
