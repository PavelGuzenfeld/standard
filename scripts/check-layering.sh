#!/usr/bin/env bash
set -uo pipefail

usage() {
    echo "Usage: $0 [root_dir]"
    echo "Environment: DEPCRUISE_TARGET"
}

case "${1:-}" in
    -h|--help) usage; exit 0 ;;
esac

ROOT="$(cd "${1:-.}" && pwd)"
DEPCRUISE_TARGET="${DEPCRUISE_TARGET:-src}"
cd "$ROOT" || exit 1

STATUS=0
RAN=0
EDGES="$(mktemp)"
trap 'rm -f "$EDGES"' EXIT

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
    local language
    for language in c cpp; do
        ast-grep run -l "$language" -p '#include $H' --json=stream . 2>/dev/null
    done |
        jq -r '[.file, .metaVariables.single.H.text] | @tsv' |
        while IFS=$'\t' read -r file quoted; do
            case "$quoted" in '"'*) ;; *) continue ;; esac
            target="$(resolve_include "$(dirname "$ROOT/$file")" "${quoted//\"/}")"
            [ -n "$target" ] && printf '%s\t%s\n' "$(normalise "$ROOT/$file")" "$target"
        done >> "$EDGES"
}

collect_gdscript_edges() {
    local file path target
    while IFS=: read -r file path; do
        case "$path" in
            res://*) target="${path#res://}" ;;
            *) target="$(dirname "$file")/$path" ;;
        esac
        [ -f "$ROOT/$target" ] && printf '%s\t%s\n' "$(normalise "$ROOT/$file")" "$(normalise "$ROOT/$target")"
    done < <(grep -rEoH --include='*.gd' '(preload|load)\("[^"]+"\)' . |
        sed -E 's#^\./##; s#:(preload|load)\("([^"]+)"\)$#:\2#') >> "$EDGES"
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
    collect_cpp_edges
    collect_gdscript_edges

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

[ -f .importlinter ] && run_python
for config in .dependency-cruiser.cjs .dependency-cruiser.js .dependency-cruiser.json; do
    [ -f "$config" ] && { run_typescript "$config"; break; }
done
[ -f .layers ] && run_layers

if [ "$RAN" -eq 0 ]; then
    echo "::notice::No layering contract declared — skipping"
fi
exit "$STATUS"
