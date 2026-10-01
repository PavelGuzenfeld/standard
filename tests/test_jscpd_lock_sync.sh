#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORKFLOW="$ROOT/.github/workflows/cpp-quality.yml"
TOOLS="$ROOT/tests/jscpd-tools"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

extract_heredoc() {
    awk -v file="$1" '
        /Install jscpd from a locked manifest/ { in_step = 1 }
        in_step && !capturing && $0 ~ ("cat > " file " <<") { capturing = 1; next }
        capturing && $0 ~ /^ *EOF$/ { exit }
        capturing { sub(/^ {10}/, ""); print }
    ' "$WORKFLOW"
}

FAILED=0
for name in package.json package-lock.json; do
    extract_heredoc "$name" > "$WORK/$name"
    if [ ! -s "$WORK/$name" ]; then
        echo "FAIL: no inline $name found in cpp-quality.yml"
        FAILED=1
    elif ! diff -u "$TOOLS/$name" "$WORK/$name"; then
        echo "FAIL: inline $name differs from tests/jscpd-tools/$name"
        FAILED=1
    else
        echo "PASS: $name in sync"
    fi
done
exit "$FAILED"
