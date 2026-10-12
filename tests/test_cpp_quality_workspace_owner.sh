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
