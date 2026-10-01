#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$ROOT/scripts/check-workflow-docs.py"
PYTHON="${PYTHON:-python3}"
FAILED=0
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$WORK/workflows" "$WORK/docs"
cat >"$WORK/workflows/sample.yml" <<'YAML'
name: Sample
on:
  workflow_call:
    inputs:
      target:
        type: string
        required: true
        description: 'Target <name> to build'
      retries:
        type: number
        default: 3
        description: 'Retry count'
      verbose:
        type: boolean
        default: false
        description: 'Print more'
      label:
        type: string
        default: 'it''s'
        description: 'Label'
jobs:
  noop:
    runs-on: ubuntu-latest
    steps:
      - run: "true"
YAML
echo "sample.yml sample.md" >"$WORK/workflow-docs.map"
cat >"$WORK/docs/sample.md" <<'MD'
# Sample

| Input | Type | Default | Description |
|-------|------|---------|-------------|
| `target` | string | required | Target &lt;name&gt; to build |
| `retries` | number | `3` | Retry count |
| `verbose` | boolean | `false` | Print more |
| `label` | string | `'it''s'` | Label |
MD

run_check() {
    "$PYTHON" "$SCRIPT" --map "$WORK/workflow-docs.map" --workflows-dir "$WORK/workflows" --docs-dir "$WORK/docs" "$@"
}

expect_pass() {
    local label="$1"
    shift
    if out=$(run_check "$@" 2>&1); then echo "PASS: $label"; else echo "FAIL: $label"; echo "$out"; FAILED=1; fi
}

expect_report() {
    local label="$1" needle="$2"
    shift 2
    local status=0 out
    out=$(run_check "$@" 2>&1) || status=$?
    if [ "$status" -eq 1 ] && grep -qF -- "$needle" <<<"$out"; then
        echo "PASS: $label"
    else
        echo "FAIL: $label (exit $status, missing: $needle)"
        echo "$out"
        FAILED=1
    fi
}

with_doc() {
    cp "$WORK/docs/sample.md" "$WORK/docs/sample.md.orig"
    sed -i "$1" "$WORK/docs/sample.md"
}

restore_doc() {
    cat "$WORK/docs/sample.md.orig" >"$WORK/docs/sample.md"
}

cp "$WORK/docs/sample.md" "$WORK/clean.md"
cat >"$WORK/docs/sample.md" <<'MD'
# Sample

Intro prose with `code` and a | pipe.

| Input | Type | Default | Description |
|-------|------|---------|-------------|
| `target` | string | required | Target &lt;name&gt; to build |
| `retries` | number | `4` | Old text |
| `verbose` | boolean | `false` | Print more |

Middle prose.

| Input | Type | Default | Description |
|-------|------|---------|-------------|
| `label` | string | `'it''s'` | Label |

Closing prose.
MD
cp "$WORK/docs/sample.md" "$WORK/stale.md"
status=0
run_check --write >/dev/null || status=$?
if [ "$status" -eq 0 ] && run_check >/dev/null 2>&1; then
    echo "PASS: --write fixes a stale table and exits 0"
else
    echo "FAIL: --write fixes a stale table (exit $status)"
    FAILED=1
fi
expected_after=$(sed -e 's/`4` | Old text/`3` | Retry count/' "$WORK/stale.md")
if [ "$(cat "$WORK/docs/sample.md")" = "$expected_after" ]; then
    echo "PASS: --write changes only the table rows and keeps prose and table split"
else
    echo "FAIL: --write changes only the table rows and keeps prose and table split"
    diff "$WORK/stale.md" "$WORK/docs/sample.md" || true
    FAILED=1
fi
cp "$WORK/docs/sample.md" "$WORK/written.md"
run_check --write >/dev/null
if cmp -s "$WORK/docs/sample.md" "$WORK/written.md"; then
    echo "PASS: --write is idempotent"
else
    echo "FAIL: --write is idempotent"
    FAILED=1
fi
cp "$WORK/clean.md" "$WORK/docs/sample.md"

expect_pass "matching table passes"

with_doc 's/`3`/`4`/'
expect_report "changed default is reported" "default is '\`4\`', workflow has '\`3\`'"
restore_doc

with_doc 's/| number |/| string |/'
expect_report "changed type is reported" "type is 'string', workflow has 'number'"
restore_doc

with_doc 's/&lt;name&gt;/<name>/'
expect_report "unescaped angle brackets are reported as a description mismatch" "description"
restore_doc

with_doc '/`retries`/{h;d};/`verbose`/{G}'
expect_report "swapped order is reported" "retries is out of workflow order"
restore_doc

with_doc '/`verbose`/d'
expect_report "missing input is reported" "input verbose is missing"
restore_doc

with_doc 's/| Input | Type |/| Input |/;s/| string | required/| required/'
expect_report "three column table is reported" "header is"
restore_doc

echo "other.yml other.md" >>"$WORK/workflow-docs.map"
cp "$WORK/workflows/sample.yml" "$WORK/workflows/other.yml"
expect_report "mapped workflow without a page is reported" "other.yml -> other.md"
sed -i '$d' "$WORK/workflow-docs.map"
rm "$WORK/workflows/other.yml"

cp "$WORK/workflows/sample.yml" "$WORK/workflows/unmapped.yml"
expect_report "workflow missing from the map is reported" "unmapped.yml: has workflow_call inputs but no line in the map"
rm "$WORK/workflows/unmapped.yml"

regenerated=$(run_check --regenerate)
expected_table=$(sed -n '3,$p' "$WORK/docs/sample.md")
if grep -qF -- "$expected_table" <<<"$regenerated"; then
    echo "PASS: --regenerate prints the documented table"
else
    echo "FAIL: --regenerate prints the documented table"
    FAILED=1
fi

if help_output=$("$PYTHON" "$SCRIPT" --help) && grep -q "^Usage: " <<<"$help_output"; then
    echo "PASS: --help prints usage on stdout"
else
    echo "FAIL: --help prints usage on stdout"
    FAILED=1
fi

status=0
err=$("$PYTHON" "$SCRIPT" --bogus 2>&1 >/dev/null) || status=$?
if [ "$status" -eq 1 ] && grep -q "^Usage: " <<<"$err"; then
    echo "PASS: rejects unknown option with usage on stderr"
else
    echo "FAIL: rejects unknown option (exit $status)"
    FAILED=1
fi

exit "$FAILED"
