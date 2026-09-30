#!/usr/bin/env bash
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
CHECK="$HERE/../scripts/check-layering.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

REQUIRED_TOOLS=(jq tsort realpath ast-grep lint-imports npx)
for tool in "${REQUIRED_TOOLS[@]}"; do
    command -v "$tool" > /dev/null || { echo "missing tool: $tool"; exit 1; }
done
[ "$(node -p 'process.versions.node.split(".")[0]')" -ge 22 ] || { echo "missing tool: node >= 22"; exit 1; }

PASS=0
FAIL=0

expect() {
    local want="$1" dir="$2" desc="$3" out rc
    out="$(bash "$CHECK" "$dir" 2>&1)"
    rc=$?
    if { [ "$want" = fail ] && [ "$rc" -ne 0 ]; } || { [ "$want" != fail ] && [ "$rc" -eq 0 ]; }; then
        if [ "$want" = skip ] && ! grep -q '^::notice::.*skip' <<<"$out"; then
            FAIL=$((FAIL + 1)); echo "  FAIL: $desc (no skip notice)"; return
        fi
        PASS=$((PASS + 1)); echo "  PASS: $desc"
    else
        FAIL=$((FAIL + 1)); echo "  FAIL: $desc (rc=$rc)"; echo "$out" | sed 's/^/    /'
    fi
}

write() {
    mkdir -p "$(dirname "$1")"
    cat > "$1"
}

python_fixture() {
    local d="$WORK/py-$1"
    mkdir -p "$d/app"
    write "$d/.importlinter" <<'CFG'
[importlinter]
root_package = app

[importlinter:contract:layers]
name = app layers
type = layers
layers =
    app.high
    app.low
CFG
    : > "$d/app/__init__.py"
    echo "VALUE = 1" > "$d/app/high.py"
    if [ "$2" = bad ]; then echo "from app import high" > "$d/app/low.py"; else echo "X = 1" > "$d/app/low.py"; fi
    echo "$d"
}

ts_fixture() {
    local d="$WORK/ts-$1"
    write "$d/.dependency-cruiser.cjs" <<'CFG'
module.exports = {
  forbidden: [
    { name: "low-not-to-high", severity: "error", from: { path: "^src/low" }, to: { path: "^src/high" } },
  ],
};
CFG
    write "$d/src/high/top.ts" <<'SRC'
export const top = 1;
SRC
    if [ "$2" = bad ]; then
        write "$d/src/low/base.ts" <<'SRC'
import { top } from "../high/top";
export const base = top;
SRC
    else
        write "$d/src/low/base.ts" <<'SRC'
export const base = 1;
SRC
    fi
    echo "$d"
}

cpp_fixture() {
    local d="$WORK/cpp-$1"
    printf 'src/low\nsrc/high\n' | write "$d/.layers"
    write "$d/src/high/top.h" <<'SRC'
#pragma once
SRC
    if [ "$2" = bad ]; then
        write "$d/src/low/base.h" <<'SRC'
#pragma once
#include "../high/top.h"
SRC
    else
        write "$d/src/low/base.h" <<'SRC'
#pragma once
SRC
    fi
    echo "$d"
}

cpp_cycle_fixture() {
    local d="$WORK/cpp-cycle"
    printf 'src\n' | write "$d/.layers"
    printf '#include "b.h"\n' | write "$d/src/a.h"
    printf '#include "a.h"\n' | write "$d/src/b.h"
    echo "$d"
}

gd_fixture() {
    local d="$WORK/gd-$1"
    printf 'scripts/low\nscripts/high\n' | write "$d/.layers"
    echo 'extends Node' | write "$d/scripts/high/top.gd"
    if [ "$2" = bad ]; then
        echo 'const Top = preload("res://scripts/high/top.gd")' | write "$d/scripts/low/base.gd"
    else
        echo 'extends Node' | write "$d/scripts/low/base.gd"
    fi
    echo "$d"
}

expect_missing_tool() {
    local missing="$1" dir="$2" desc="$3" shim="$WORK/shim-$1" tool out rc
    mkdir -p "$shim"
    for tool in "${REQUIRED_TOOLS[@]}" node mktemp rm dirname tr sed grep cat mkdir; do
        [ "$tool" = "$missing" ] || ln -sf "$(command -v "$tool")" "$shim/$tool"
    done
    out="$(PATH="$shim" "$BASH" "$CHECK" "$dir" 2>&1 > /dev/null)"
    rc=$?
    if [ "$rc" -ne 0 ] && grep -q "^missing tool: $missing" <<<"$out"; then
        PASS=$((PASS + 1)); echo "  PASS: $desc"
    else
        FAIL=$((FAIL + 1)); echo "  FAIL: $desc (rc=$rc)"; echo "$out" | sed 's/^/    /'
    fi
}

echo "=== layering contract ==="
expect fail "$(python_fixture bad bad)" "python: lower layer importing upper fails"
expect pass "$(python_fixture good good)" "python: no upward import passes"
expect fail "$(ts_fixture bad bad)" "typescript: lower layer importing upper fails"
expect pass "$(ts_fixture good good)" "typescript: no upward import passes"
expect fail "$(cpp_fixture bad bad)" "cpp: lower layer including upper fails"
expect pass "$(cpp_fixture good good)" "cpp: no upward include passes"
expect fail "$(cpp_cycle_fixture)" "cpp: include cycle fails"
expect fail "$(gd_fixture bad bad)" "gdscript: lower layer preloading upper fails"
expect pass "$(gd_fixture good good)" "gdscript: no upward preload passes"
mkdir -p "$WORK/none"
expect skip "$WORK/none" "no contract file skips with notice"
expect_missing_tool jq "$(cpp_fixture good good)" "layers: missing jq is reported and fails"
expect_missing_tool ast-grep "$(cpp_fixture good good)" "layers: missing ast-grep is reported and fails"
expect_missing_tool lint-imports "$(python_fixture good good)" "python: missing lint-imports is reported and fails"
expect_missing_tool npx "$(ts_fixture good good)" "typescript: missing npx is reported and fails"

echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
