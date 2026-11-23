#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "Usage: $0 <workflow_file> <jscpd_tools_dir>"
    echo ""
    echo "Rewrite the inline package.json and package-lock.json heredocs of the"
    echo "'Install jscpd from a locked manifest' step in <workflow_file> from the"
    echo "same files in <jscpd_tools_dir>. Reads the manifests as data only."
}

case "${1:-}" in
    -h|--help) usage; exit 0 ;;
    -*) usage >&2; exit 1 ;;
esac
[ $# -eq 2 ] || { usage >&2; exit 1; }

WORKFLOW="$1"
TOOLS="$2"
HEREDOC_INDENT="          "

for name in package.json package-lock.json; do
    [ -f "$TOOLS/$name" ] || { echo "Missing $TOOLS/$name" >&2; exit 1; }
    jq empty "$TOOLS/$name" || { echo "$TOOLS/$name is not valid JSON" >&2; exit 1; }
    ! grep -qF '${{' "$TOOLS/$name" || { echo "$TOOLS/$name contains an Actions expression" >&2; exit 1; }
done

SYNCED=$(mktemp "$WORKFLOW.synced.XXXXXX")
trap 'rm -f "$SYNCED"' EXIT

awk -v tools="$TOOLS" -v indent="$HEREDOC_INDENT" '
    /Install jscpd from a locked manifest/ { in_step = 1 }
    in_step && !skipping && match($0, /cat > package(-lock)?\.json <</) {
        print
        name = substr($0, RSTART + 6, RLENGTH - 9)
        path = tools "/" name
        while ((getline line < path) > 0) print indent line
        close(path)
        skipping = 1
        next
    }
    skipping && $0 ~ /^ *EOF$/ { skipping = 0; replaced++ }
    skipping { next }
    { print }
    END { if (replaced != 2) exit 1 }
' "$WORKFLOW" > "$SYNCED"
chmod --reference="$WORKFLOW" "$SYNCED"
mv "$SYNCED" "$WORKFLOW"
