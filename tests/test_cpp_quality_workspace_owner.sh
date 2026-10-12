#!/usr/bin/env bash
set -euo pipefail

ROOT="${OWNER_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
WORKFLOW="$ROOT/.github/workflows/cpp-quality.yml"

jobs_missing_ownership_restore() {
    awk '
        function flush() {
            if (job != "" && mounts && !restored) print job
        }
        /^  [a-z][a-z-]*:$/ { flush(); job = $1; mounts = 0; restored = 0; always = 0; next }
        /github\.workspace \}\}:/ { mounts = 1 }
        /^        if: always\(\)/ { always = 1; next }
        /^      - name:/ { always = 0 }
        /chown -R "\$\(id -u\):\$\(id -g\)"/ && always { restored = 1 }
        END { flush() }
    ' "$WORKFLOW"
}

MISSING=$(jobs_missing_ownership_restore)
if [ -n "$MISSING" ]; then
    echo "FAIL: jobs that mount the workspace in docker but never chown it back to the runner uid:"
    echo "$MISSING"
    exit 1
fi
echo "PASS: every docker job restores workspace ownership in an always() step"

SCRATCH=$(mktemp -d)
trap 'rm -rf "$SCRATCH"' EXIT

awk -v dir="$SCRATCH" '
    /^      - name:/ { sub(/^      - name: */, ""); name = $0; gsub(/[^A-Za-z0-9]+/, "_", name); inrun = 0; next }
    /^        run: \|$/ { inrun = 1; n++; file = sprintf("%s/%03d_%s.sh", dir, n, name); next }
    inrun && /^          / { sub(/^          /, ""); print > file; next }
    inrun && /^$/ { print "" > file; next }
    { inrun = 0 }
' "$WORKFLOW"

SYNTAX_FAILED=0
for script in "$SCRATCH"/*.sh; do
    if ! bash -n "$script" 2>/dev/null; then
        echo "FAIL: run block does not parse: $(basename "$script" .sh)"
        SYNTAX_FAILED=1
    fi
done
[ "$SYNTAX_FAILED" -eq 0 ] || exit 1
echo "PASS: every run block parses under bash -n"
