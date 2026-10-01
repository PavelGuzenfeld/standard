#!/usr/bin/env bash
set -uo pipefail

GENERATOR="$(cd "$(dirname "$0")/.." && pwd)/scripts/generate-workflow.sh"
VALIDATOR="$(cd "$(dirname "$0")" && pwd)/renovate-tools/node_modules/.bin/renovate-config-validator"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
FAILURES=0

generate() {
    local name="$1"
    shift
    mkdir -p "$WORK/$name"
    (cd "$WORK/$name" && touch pyproject.toml \
        && bash "$GENERATOR" --non-interactive --output-dir "$WORK/$name/.github/workflows" "$@" >/dev/null 2>&1)
}

check() {
    local label="$1"
    shift
    if "$@" >/dev/null; then
        echo "  PASS: $label"
    else
        FAILURES=$((FAILURES + 1)); echo "  FAIL: $label"
    fi
}

generate default
check "default writes no dependency bot config" \
    bash -c '[ ! -e "$1/.github/renovate.json" ] && [ ! -e "$1/.github/dependabot.yml" ]' _ "$WORK/default"

generate renovate --dependency-bot renovate
check "renovate writes renovate.json" test -f "$WORK/renovate/.github/renovate.json"
check "renovate writes no dependabot.yml" test ! -e "$WORK/renovate/.github/dependabot.yml"
check "renovate.json is valid JSON" jq -e . "$WORK/renovate/.github/renovate.json"
check "renovate.json enables the conan manager" \
    jq -e '.enabledManagers | index("conan") != null' "$WORK/renovate/.github/renovate.json"
check "renovate.json extends config:recommended" \
    jq -e '.extends | index("config:recommended") != null' "$WORK/renovate/.github/renovate.json"
check "renovate.json pins github-actions digests" \
    jq -e '.["github-actions"].pinDigests == true' "$WORK/renovate/.github/renovate.json"

check "renovate.json passes renovate-config-validator --strict" \
    "$VALIDATOR" --strict "$WORK/renovate/.github/renovate.json"

generate both --dependency-bot both
check "both writes renovate.json" test -f "$WORK/both/.github/renovate.json"
check "both writes dependabot.yml" test -f "$WORK/both/.github/dependabot.yml"

generate dependabot --dependency-bot dependabot
check "dependabot writes dependabot.yml only" \
    bash -c '[ -f "$1/.github/dependabot.yml" ] && [ ! -e "$1/.github/renovate.json" ]' _ "$WORK/dependabot"

unknown_bot_status=0
(cd "$WORK/default" && bash "$GENERATOR" --non-interactive --dependency-bot nope >/dev/null 2>&1) || unknown_bot_status=$?
check "unknown bot exits 1" test "$unknown_bot_status" -eq 1

[ "$FAILURES" -eq 0 ]
