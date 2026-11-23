#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SYNC="$ROOT/scripts/sync-jscpd-inline.sh"
LOCK_SYNC_TEST="$ROOT/tests/test_jscpd_lock_sync.sh"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

cp "$ROOT/.github/workflows/cpp-quality.yml" "$WORK/cpp-quality.yml"
cp -r "$ROOT/tests/jscpd-tools" "$WORK/tools"
rm -rf "$WORK/tools/node_modules"
sed -i 's/5\.4\.3/9.9.9/g' "$WORK/tools/package.json" "$WORK/tools/package-lock.json"

FAILED=0

if WORKFLOW="$WORK/cpp-quality.yml" TOOLS="$WORK/tools" bash "$LOCK_SYNC_TEST" >/dev/null 2>&1; then
    echo "FAIL: bumped tools should be out of sync before the sync runs"
    FAILED=1
else
    echo "PASS: bumped tools are out of sync before the sync runs"
fi

bash "$SYNC" "$WORK/cpp-quality.yml" "$WORK/tools"

if WORKFLOW="$WORK/cpp-quality.yml" TOOLS="$WORK/tools" bash "$LOCK_SYNC_TEST" >/dev/null; then
    echo "PASS: inline manifest matches tests/jscpd-tools after the sync"
else
    echo "FAIL: inline manifest still differs after the sync"
    FAILED=1
fi

if diff -q <(grep -vE '9\.9\.9' "$WORK/cpp-quality.yml") <(grep -vE '5\.4\.3' "$ROOT/.github/workflows/cpp-quality.yml") >/dev/null; then
    echo "PASS: the sync touches only the manifest lines"
else
    echo "FAIL: the sync changed lines outside the manifest"
    FAILED=1
fi

before=$(sha256sum "$WORK/cpp-quality.yml")
bash "$SYNC" "$WORK/cpp-quality.yml" "$WORK/tools"
if [ "$before" = "$(sha256sum "$WORK/cpp-quality.yml")" ]; then
    echo "PASS: a second sync is a no-op"
else
    echo "FAIL: a second sync changed the workflow"
    FAILED=1
fi

exit "$FAILED"
