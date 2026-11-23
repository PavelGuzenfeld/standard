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

expect_rejected_and_untouched() {
    local label="$1" workflow="$2" tools="$3" status=0 before after
    before=$(sha256sum "$workflow")
    bash "$SYNC" "$workflow" "$tools" >/dev/null 2>&1 || status=$?
    after=$(sha256sum "$workflow")
    if [ "$status" -ne 0 ] && [ "$before" = "$after" ] && ! compgen -G "$(dirname "$workflow")/*.synced*" >/dev/null; then
        echo "PASS: $label"
    else
        echo "FAIL: $label (exit $status)"
        FAILED=1
    fi
}

REJECT="$WORK/reject"
mkdir -p "$REJECT/tools"
cp "$ROOT/tests/jscpd-tools/package.json" "$ROOT/tests/jscpd-tools/package-lock.json" "$REJECT/tools/"

cp "$ROOT/.github/workflows/cpp-quality.yml" "$REJECT/cpp-quality.yml"
sed -i '0,/"private":true/s/"private":true/"private":true,"x":"${{ secrets.TOKEN }}"/' "$REJECT/tools/package.json"
expect_rejected_and_untouched "an expression in a manifest is rejected" "$REJECT/cpp-quality.yml" "$REJECT/tools"

cp "$ROOT/tests/jscpd-tools/package.json" "$REJECT/tools/package.json"
sed -i '0,/"name": "jscpd-runner"/s/"name": "jscpd-runner"/"name": "${{ secrets.TOKEN }}"/' "$REJECT/tools/package-lock.json"
expect_rejected_and_untouched "an expression in the lockfile is rejected" "$REJECT/cpp-quality.yml" "$REJECT/tools"

cp "$ROOT/tests/jscpd-tools/package-lock.json" "$REJECT/tools/package-lock.json"
echo '{"name":' > "$REJECT/tools/package.json"
expect_rejected_and_untouched "a manifest that is not JSON is rejected" "$REJECT/cpp-quality.yml" "$REJECT/tools"

cp "$ROOT/tests/jscpd-tools/package.json" "$REJECT/tools/package.json"
echo 'not json' > "$REJECT/tools/package-lock.json"
expect_rejected_and_untouched "a lockfile that is not JSON is rejected" "$REJECT/cpp-quality.yml" "$REJECT/tools"

cp "$ROOT/tests/jscpd-tools/package-lock.json" "$REJECT/tools/package-lock.json"
awk '/cat > package-lock.json <</ { skipping = 1 } skipping && /^ *EOF$/ { skipping = 0; next } !skipping' \
    "$ROOT/.github/workflows/cpp-quality.yml" > "$REJECT/cpp-quality.yml"
expect_rejected_and_untouched "a workflow missing the lockfile heredoc is rejected" "$REJECT/cpp-quality.yml" "$REJECT/tools"

awk '/cat > package.json <</ { skipping = 1 } skipping && /^ *EOF$/ { skipping = 0; next } !skipping' \
    "$ROOT/.github/workflows/cpp-quality.yml" > "$REJECT/cpp-quality.yml"
expect_rejected_and_untouched "a workflow missing the package heredoc is rejected" "$REJECT/cpp-quality.yml" "$REJECT/tools"

exit "$FAILED"
