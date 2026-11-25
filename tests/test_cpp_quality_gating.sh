#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORKFLOW="$ROOT/.github/workflows/cpp-quality.yml"
FAILED=0
SCRATCH=$(mktemp -d)
trap 'rm -rf "$SCRATCH"' EXIT

fail() {
    echo "FAIL: $*"
    FAILED=1
}

exclude_filter_ids() {
    awk '
        /^  [a-z][a-z-]*:$/ { job = $1; sub(/:$/, "", job) }
        /^      - name:/ { in_filter = ($0 ~ /- name: Filter excluded paths$/) ; next }
        in_filter && /^        id: / { print job, $2; in_filter = 0 }
    ' "$WORKFLOW"
}

jobs_with_exclude_filter() {
    awk '
        /^  [a-z][a-z-]*:$/ { job = $1; sub(/:$/, "", job) }
        /^      - name: Filter excluded paths$/ { print job }
    ' "$WORKFLOW"
}

steps_gated_on_changed_without_filter() {
    local job="$1" filter_id="$2"
    awk -v want="$job" -v guard="steps.${filter_id}.outputs.skip != 'true'" '
        /^  [a-z][a-z-]*:$/ { job = $1; sub(/:$/, "", job); seen_filter = 0 }
        job != want { next }
        /^      - name:/ { name = $0; sub(/^      - name: */, "", name); in_filter = 0 }
        /^      - name: Filter excluded paths$/ { seen_filter = 1; in_filter = 1; next }
        seen_filter && !in_filter && /^        if:.*steps\.changed\.outputs\.skip == .false./ && index($0, guard) == 0 { print name }
    ' "$WORKFLOW"
}

filter_run_block() {
    local job="$1"
    awk -v want="$job" '
        /^  [a-z][a-z-]*:$/ { job = $1; sub(/:$/, "", job) }
        job != want { next }
        /^      - name:/ { in_filter = ($0 ~ /- name: Filter excluded paths$/); inrun = 0; next }
        in_filter && /^        run: \|$/ { inrun = 1; next }
        inrun && /^          / { sub(/^          /, ""); print; next }
        inrun && /^$/ { print ""; next }
        { inrun = 0 }
    ' "$WORKFLOW"
}

JOBS=$(jobs_with_exclude_filter)
[ -n "$JOBS" ] || fail "no job in cpp-quality.yml has a 'Filter excluded paths' step"
IDS=$(exclude_filter_ids)

for job in $JOBS; do
    filter_id=$(echo "$IDS" | awk -v j="$job" '$1 == j { print $2 }')
    if [ -z "$filter_id" ]; then
        fail "$job: 'Filter excluded paths' has no id, so its skip output is unreadable"
        continue
    fi
    UNGUARDED=$(steps_gated_on_changed_without_filter "$job" "$filter_id")
    if [ -n "$UNGUARDED" ]; then
        fail "$job: steps still run after every changed file is excluded:"
        echo "$UNGUARDED" | sed 's/^/  /'
    fi

    work="$SCRATCH/$job"
    mkdir -p "$work"
    printf 'third_party/\nvendor/lib.hpp\n' > "$work/exclude.txt"
    printf 'third_party/a.cpp\nvendor/lib.hpp\n' > "$work/changed.txt"
    : > "$work/output"
    filter_run_block "$job" | sed "s#/tmp/changed_cpp_files.txt#$work/changed.txt#g" > "$work/filter.sh"
    (cd "$work" && GITHUB_OUTPUT="$work/output" INPUT_EXCLUDE_FILE="$work/exclude.txt" bash "$work/filter.sh" >/dev/null)
    grep -qx 'skip=true' "$work/output" || fail "$job: filter step does not write skip=true when every changed file is excluded"
done
[ "$FAILED" -eq 0 ] && echo "PASS: every job skips its analysis when the exclude filter leaves no files"

SECRET_BLOCK=$(awk '
    /^    secrets:$/ { insec = 1; next }
    insec && /^    [a-z]/ { insec = 0 }
    insec && /^[a-z]/ { insec = 0 }
    insec { print }
' "$WORKFLOW")
echo "$SECRET_BLOCK" | grep -q '^      checkout_token:$' || fail "workflow_call declares no checkout_token secret"
echo "$SECRET_BLOCK" | awk '/^      checkout_token:$/ { s = 1; next } s && /^      [a-z]/ { s = 0 } s' | grep -q 'required: false' \
    || fail "checkout_token secret is not optional"

CHECKOUTS_WITHOUT_TOKEN=$(awk '
    function flush() { if (submodules && !token) print name; submodules = 0; token = 0 }
    /^      - name:/ { flush(); name = $0; sub(/^      - name: */, "", name) }
    /^  [a-z][a-z-]*:$/ { flush() }
    /^          submodules: \$\{\{ inputs\.checkout_submodules \}\}$/ { submodules = 1 }
    /^          token: \$\{\{ (steps\.app-token\.outputs\.token \|\| )?secrets\.checkout_token \|\| github\.token \}\}$/ { token = 1 }
    END { flush() }
' "$WORKFLOW")
SUBMODULE_CHECKOUTS=$(grep -c 'submodules: ${{ inputs.checkout_submodules }}' "$WORKFLOW" || true)
[ "$SUBMODULE_CHECKOUTS" -gt 0 ] || fail "no checkout passes inputs.checkout_submodules"
if [ -n "$CHECKOUTS_WITHOUT_TOKEN" ]; then
    fail "$(echo "$CHECKOUTS_WITHOUT_TOKEN" | wc -l) of $SUBMODULE_CHECKOUTS submodule checkouts ignore checkout_token"
fi
[ "$FAILED" -eq 0 ] && echo "PASS: every submodule checkout uses checkout_token when given"

flawfinder_run_block() {
    awk '
        /^  [a-z][a-z-]*:$/ { job = $1; sub(/:$/, "", job) }
        job != "flawfinder" { next }
        /^      - name:/ { in_step = ($0 ~ /- name: Run flawfinder$/); inrun = 0; next }
        in_step && /^        run: \|$/ { inrun = 1; next }
        inrun && /^          / { sub(/^          /, ""); print; next }
        inrun && /^$/ { print ""; next }
        { inrun = 0 }
    ' "$WORKFLOW"
}

work="$SCRATCH/flawfinder"
mkdir -p "$work/bin"
printf 'src/a.cpp\nsrc/b.hpp\n' > "$work/changed.txt"
printf '#!/bin/sh\necho "$@" >> "%s/argv"\n' "$work" > "$work/bin/flawfinder"
chmod +x "$work/bin/flawfinder"
: > "$work/output"
flawfinder_run_block | sed "s#/tmp/changed_cpp_files.txt#$work/changed.txt#g" > "$work/run.sh"
(cd "$work" && PATH="$work/bin:$PATH" GITHUB_OUTPUT="$work/output" INPUT_FLAWFINDER_MIN_LEVEL=1 bash -e "$work/run.sh" >/dev/null) \
    || fail "flawfinder step exits non-zero on a clean scan of two files"
grep -q ' src/a.cpp src/b.hpp$' "$work/argv" 2>/dev/null || fail "flawfinder is not invoked with every changed file"
grep -qx 'hits=0' "$work/output" || fail "flawfinder step does not reach its hits output"
[ "$FAILED" -eq 0 ] && echo "PASS: flawfinder step scans every changed file under bash -e"

for name in app_id app_private_key; do
    echo "${SECRET_BLOCK}" | grep -q "^      ${name}:$" || fail "workflow_call declares no ${name} secret"
    echo "${SECRET_BLOCK}" | awk -v key="${name}" '$(0) == "      " key ":" { s = 1; next } s && /^      [a-z]/ { s = 0 } s' | grep -q 'required: false' \
        || fail "${name} secret is not optional"
done

CHECKOUTS_WITHOUT_TOKEN=$(awk '
    /^  [a-z][a-z-]*:$/ { job = $(1); app = 0 }
    /&checkout-app-token|\*checkout-app-token/ { app = 1 }
    /^          submodules: / && !app { print job }
' "${WORKFLOW}")
[ -z "${CHECKOUTS_WITHOUT_TOKEN}" ] || fail "submodule jobs without App authentication: ${CHECKOUTS_WITHOUT_TOKEN}"
grep -q 'permission-contents: read' "${WORKFLOW}" || fail "checkout App token does not restrict contents to read"
grep -q 'steps.app-token.outputs.token || secrets.checkout_token || github.token' "${WORKFLOW}" \
    || fail "checkout does not prefer the App token while preserving PAT and default-token fallbacks"

exit "${FAILED}"
