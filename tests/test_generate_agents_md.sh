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

ALL_YES_ANSWERS='y y y y y  y y y y y y y  y y y y y y'
(cd "$WORK" && tr ' ' '\n' <<<"$ALL_YES_ANSWERS" | bash "$GENERATOR" --output "$WORK/all_yes.md" >/dev/null 2>&1)

expected_all_yes="$(
    grep -v -e '^> ' -e 'Hardening verification' -e 'release-hardened' "$TEMPLATE" \
        | sed -e 's/ruff (or flake8)/ruff/' -e 's/ruff (preferred) or flake8/ruff/' -e 's|ruff/flake8|ruff|' \
        | cat -s
)"
if diff <(echo "$expected_all_yes") "$WORK/all_yes.md" >"$WORK/all_yes.diff"; then
    echo "  PASS: all options yes reproduces the template modulo the documented filters"
else
    FAILURES=$((FAILURES + 1)); echo "  FAIL: all-yes output differs from the filtered template:"; head -20 "$WORK/all_yes.diff" | sed 's/^/    /'
fi

CPP_ONLY="$(mktemp -d)"
(cd "$CPP_ONLY" && touch CMakeLists.txt && bash "$GENERATOR" --non-interactive --output "$CPP_ONLY/AGENTS.md" >/dev/null 2>&1)
for absent in 'Built-in exemptions' '### Banned Patterns' '**clang-format**' 'ASan' 'Python Conventions' 'Sanitizer Build Presets' 'Adding File Naming Exceptions'; do
    if grep -qF -- "$absent" "$CPP_ONLY/AGENTS.md"; then
        FAILURES=$((FAILURES + 1)); echo "  FAIL: opt-in section present with options off: $absent"
    else
        echo "  PASS: absent with options off: $absent"
    fi
done
for present in '## Security Hygiene' '## Git & PR Rules' '### Always Enforced'; do
    if grep -qF -- "$present" "$CPP_ONLY/AGENTS.md"; then
        echo "  PASS: present with options off: $present"
    else
        FAILURES=$((FAILURES + 1)); echo "  FAIL: missing with options off: $present"
    fi
done
rm -rf "$CPP_ONLY"

[ "$FAILURES" -eq 0 ]
