#!/usr/bin/env bash
set -euo pipefail

SCAN_DIR="${1:-.github/workflows}"

if [ ! -d "$SCAN_DIR" ]; then
    echo "Directory not found: $SCAN_DIR"
    exit 1
fi

VIOLATIONS=0

for file in "$SCAN_DIR"/*.yml "$SCAN_DIR"/*.yaml; do
    [ -f "$file" ] || continue

    if grep -q 'pull_request_target' "$file"; then
        if grep -qE 'github\.event\.pull_request\.head\.(sha|ref)' "$file"; then
            echo "ERROR: $file: pull_request_target with checkout of PR head ref"
            VIOLATIONS=$((VIOLATIONS + 1))
        fi
    fi

    LINE_NUM=0
    IN_RUN=false
    while IFS= read -r line || [ -n "$line" ]; do
        LINE_NUM=$((LINE_NUM + 1))
        if echo "$line" | grep -qE '^\s+run:\s*[|>]?\s*$' || echo "$line" | grep -qE '^\s+run:\s+\S'; then
            IN_RUN=true
        elif $IN_RUN && echo "$line" | grep -qE '^\s+[a-zA-Z_-]+:' && ! echo "$line" | grep -qE '^\s+#'; then
            IN_RUN=false
        fi

        if $IN_RUN; then
            if echo "$line" | grep -qE '\$\{\{\s*github\.event\.pull_request\.(title|body|head\.ref)\s*\}\}'; then
                echo "ERROR: $file:$LINE_NUM: PR-controlled input in run: step"
                VIOLATIONS=$((VIOLATIONS + 1))
            fi
            if echo "$line" | grep -qE '\$\{\{\s*github\.event\.issue\.(title|body)\s*\}\}'; then
                echo "ERROR: $file:$LINE_NUM: issue-controlled input in run: step"
                VIOLATIONS=$((VIOLATIONS + 1))
            fi
            if echo "$line" | grep -qE '\$\{\{\s*github\.event\.comment\.body\s*\}\}'; then
                echo "ERROR: $file:$LINE_NUM: comment body in run: step"
                VIOLATIONS=$((VIOLATIONS + 1))
            fi
        fi
    done < "$file"
done

if [ "$VIOLATIONS" -gt 0 ]; then
    echo ""
    echo "Found $VIOLATIONS dangerous workflow pattern(s)."
    exit 1
else
    echo "No dangerous workflow patterns found in $SCAN_DIR."
    exit 0
fi
