#!/usr/bin/env bash
set -uo pipefail

usage() {
    echo "Usage: $0 [root_dir]"
    echo "Environment: DEPCRUISE_TARGET"
}

case "${1:-}" in
    -h|--help) usage; exit 0 ;;
    -*) usage >&2; exit 1 ;;
esac
[ $# -le 1 ] || { usage >&2; exit 1; }

ROOT="$(cd "${1:-.}" && pwd)"
DEPCRUISE_TARGET="${DEPCRUISE_TARGET:-src}"
cd "$ROOT" || exit 1

STATUS=0
RAN=0
EDGES="$(mktemp)"
trap 'rm -f "$EDGES" "$EDGES.matches" "$EDGES.matches.tsv" "$EDGES.refs" "$EDGES.err"' EXIT

require_tools() {
    local tool missing=0
    for tool in "$@"; do
        command -v "$tool" > /dev/null || { echo "missing tool: $tool" >&2; missing=1; }
    done
    [ "$missing" -eq 0 ] || exit 1
}

require_node_22() {
    local major
    major="$(node -p 'process.versions.node.split(".")[0]')"
    [ "$major" -ge 22 ] || { echo "missing tool: node >= 22" >&2; exit 1; }
}

run_python() {
    RAN=1
    echo "import-linter: .importlinter"
    lint-imports || STATUS=1
}

run_typescript() {
    local config="$1"
    RAN=1
    echo "dependency-cruiser: $config"
    if [ -x node_modules/.bin/depcruise ]; then
        npx depcruise --config "$config" "$DEPCRUISE_TARGET" || STATUS=1
    else
        npx --yes -p dependency-cruiser -p typescript@5 depcruise --config "$config" "$DEPCRUISE_TARGET" || STATUS=1
    fi
}

normalise() {
    realpath -m --relative-to="$ROOT" "$1"
}

resolve_include() {
    local from_dir="$1" header="$2" base
    for base in "$from_dir" "$ROOT" "$ROOT/include"; do
        [ -f "$base/$header" ] && { normalise "$base/$header"; return; }
    done
}

collect_cpp_edges() {
    local language file quoted target ast_grep_status matches="$EDGES.matches"
    : > "$matches"
    for language in c cpp; do
        ast_grep_status=0
        ast-grep run -l "$language" -p '#include $H' --json=stream . >> "$matches" 2> "$EDGES.err" ||
            ast_grep_status=$?
        if [ "$ast_grep_status" -gt 1 ] || { [ "$ast_grep_status" -eq 1 ] && [ -s "$EDGES.err" ]; }; then
            echo "::error::ast-grep failed (language: $language): $(tr '\n' ' ' < "$EDGES.err")" >&2
            return 1
        fi
    done
    jq -r '[.file, .metaVariables.single.H.text] | @tsv' < "$matches" > "$matches.tsv" ||
        { echo "::error::jq failed parsing ast-grep output" >&2; return 1; }
    while IFS=$'\t' read -r file quoted; do
        case "$quoted" in '"'*) ;; *) continue ;; esac
        target="$(resolve_include "$(dirname "$ROOT/$file")" "${quoted//\"/}")"
        if [ -n "$target" ]; then
            printf '%s\t%s\n' "$(normalise "$ROOT/$file")" "$target" >> "$EDGES"
        fi
    done < "$matches.tsv"
}

collect_gdscript_edges() {
    local file path target grep_status=0 refs="$EDGES.refs"
    grep -rEoH --include='*.gd' '(preload|load)\("[^"]+"\)' . > "$refs" || grep_status=$?
    [ "$grep_status" -le 1 ] || { echo "::error::grep failed scanning GDScript" >&2; return 1; }
    while IFS=: read -r file path; do
        case "$path" in
            res://*) target="${path#res://}" ;;
            *) target="$(dirname "$file")/$path" ;;
        esac
        if [ -f "$ROOT/$target" ]; then
            printf '%s\t%s\n' "$(normalise "$ROOT/$file")" "$(normalise "$ROOT/$target")"
        fi
    done < <(sed -E 's#^\./##; s#:(preload|load)\("([^"]+)"\)$#:\2#' "$refs") >> "$EDGES"
}

layer_index() {
    local path="$1" i
    for i in "${!LAYERS[@]}"; do
        case "$path" in "${LAYERS[$i]}"|"${LAYERS[$i]}"/*) echo "$i"; return ;; esac
    done
}

run_layers() {
    RAN=1
    echo "layers: .layers"
    mapfile -t LAYERS < <(grep -vE '^\s*$' .layers | sed -E 's#/+$##')
    collect_cpp_edges || STATUS=1
    collect_gdscript_edges || STATUS=1

    local from to from_layer to_layer
    while IFS=$'\t' read -r from to; do
        from_layer="$(layer_index "$from")"
        to_layer="$(layer_index "$to")"
        if [ -n "$from_layer" ] && [ -n "$to_layer" ] && [ "$from_layer" -lt "$to_layer" ]; then
            echo "::error file=$from::${LAYERS[$from_layer]} must not depend on ${LAYERS[$to_layer]} ($to)"
            STATUS=1
        fi
    done < "$EDGES"

    if ! tsort "$EDGES" > /dev/null 2> "$EDGES.err"; then
        echo "::error::dependency cycle: $(tr '\n' ' ' < "$EDGES.err")"
        STATUS=1
    fi
    rm -f "$EDGES.err"
}

TYPESCRIPT_CONFIG=""
for config in .dependency-cruiser.cjs .dependency-cruiser.js .dependency-cruiser.json; do
    [ -f "$config" ] && { TYPESCRIPT_CONFIG="$config"; break; }
done

[ -f .importlinter ] && require_tools lint-imports
[ -n "$TYPESCRIPT_CONFIG" ] && { require_tools npx node; require_node_22; }
[ -f .layers ] && require_tools jq tsort realpath ast-grep grep

[ -f .importlinter ] && run_python
[ -n "$TYPESCRIPT_CONFIG" ] && run_typescript "$TYPESCRIPT_CONFIG"
[ -f .layers ] && run_layers

if [ "$RAN" -eq 0 ]; then
    echo "::notice::No layering contract declared — skipping"
fi
exit "$STATUS"
