#!/usr/bin/env bash
set -euo pipefail

ROOT="${PINS_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"

input_default() {
    awk -v input="$2" '
        $0 ~ ("^ +" input ":$") { found = 1; next }
        found && /default:/ { gsub(/.*default: *\x27|\x27.*/, ""); print; exit }
    ' "$1"
}

pre_commit_ruff_rev() {
    awk '
        /ruff-pre-commit/ { found = 1; next }
        found && /rev:/ { sub(/.*rev: *v?/, ""); print; exit }
    ' "$1"
}

WORKFLOW_PIN=$(input_default "$ROOT/.github/workflows/python-quality.yml" ruff_version)
ACTION_PIN=$(input_default "$ROOT/actions/ruff-check/action.yml" ruff_version)
PRE_COMMIT_PIN=$(pre_commit_ruff_rev "$ROOT/.pre-commit-config.yaml")

FAILED=0
if [ -z "$WORKFLOW_PIN" ] || [ "$WORKFLOW_PIN" != "$ACTION_PIN" ] || [ "$WORKFLOW_PIN" != "$PRE_COMMIT_PIN" ]; then
    echo "FAIL: ruff pins differ: python-quality=$WORKFLOW_PIN ruff-check=$ACTION_PIN pre-commit=$PRE_COMMIT_PIN"
    FAILED=1
else
    echo "PASS: ruff pinned to $WORKFLOW_PIN everywhere"
fi

exit "$FAILED"
