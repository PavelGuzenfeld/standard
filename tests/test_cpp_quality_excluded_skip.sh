#!/usr/bin/env bash
set -euo pipefail

ROOT="${SKIP_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
WORKFLOW="$ROOT/.github/workflows/cpp-quality.yml"
FILTER_ID="filter-excluded"

filter_steps_without_id() {
    awk -v id="$FILTER_ID" '
        /^  [a-z][a-z-]*:$/ { job = $1 }
        /^      - name: Filter excluded paths$/ { inside = 1; found = 0; next }
        inside && /^        id: / { found = ($2 == id); next }
        inside && /^        run:/ { if (!found) print job; inside = 0 }
    ' "$WORKFLOW"
}

ungated_steps_after_filter() {
    awk -v id="$FILTER_ID" '
        function flush() {
            if (step != "" && filtered && on_changed && !on_filter) print job " / " step
        }
        /^  [a-z][a-z-]*:$/ { flush(); step = ""; job = $1; filtered = 0; next }
        /^      - name:/ {
            flush()
            sub(/^      - name: */, ""); step = $0
            on_changed = 0; on_filter = 0
            if (step == "Filter excluded paths") { filtered = 1; step = "" }
            next
        }
        /^        if:/ {
            if (index($0, "steps.changed.outputs.skip")) on_changed = 1
            if (index($0, "steps." id ".outputs.skip != '"'"'true'"'"'")) on_filter = 1
        }
        END { flush() }
    ' "$WORKFLOW"
}

NO_ID=$(filter_steps_without_id)
if [ -n "$NO_ID" ]; then
    echo "FAIL: jobs whose 'Filter excluded paths' step has no id '$FILTER_ID', so its skip output is never read:"
    echo "$NO_ID"
    exit 1
fi
echo "PASS: every 'Filter excluded paths' step has id $FILTER_ID"

UNGATED=$(ungated_steps_after_filter)
if [ -n "$UNGATED" ]; then
    echo "FAIL: steps after the exclusion filter that ignore its skip output:"
    echo "$UNGATED"
    exit 1
fi
echo "PASS: every analysis step after the exclusion filter is gated on its skip output"
