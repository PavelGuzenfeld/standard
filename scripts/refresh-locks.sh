#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REQUIREMENTS_DIR="$ROOT/.github/requirements"
DOCKER_IMAGE="python:3.12-slim"
UV_FLAGS="--generate-hashes --no-annotate --no-header --python-version 3.12 --upgrade"
INLINE_TARGETS=(
    "cpp-quality.yml flawfinder"
    "cpp-quality.yml diff-cover"
    "infra-lint.yml cmakelang"
)

usage() {
    echo "Usage: $0 [--list]"
    echo ""
    echo "Recompile every .github/requirements/*.in into its hashed .txt with uv."
    echo "Then print the hashed blocks to paste into the inline REQUIREMENTS heredocs"
    echo "of the workflows. Workflow files are never edited."
    echo ""
    echo "Uses uv from PATH, else runs it in Docker image $DOCKER_IMAGE."
    echo ""
    echo "Options:"
    echo "  --list      Print the targets and exit without running uv"
    echo "  -h, --help  Show this help message"
}

list_targets() {
    local source
    for source in "$REQUIREMENTS_DIR"/*.in; do
        local relative="${source#"$ROOT"/}"
        echo "compile $relative -> ${relative%.in}.txt"
    done
    local target workflow package
    for target in "${INLINE_TARGETS[@]}"; do
        read -r workflow package <<<"$target"
        echo "inline  .github/workflows/$workflow: $package"
    done
}

uv_commands() {
    local source
    for source in "$REQUIREMENTS_DIR"/*.in; do
        local relative="${source#"$ROOT"/}"
        echo "uv pip compile $UV_FLAGS -q -o ${relative%.in}.txt $relative"
    done
    local target workflow package
    for target in "${INLINE_TARGETS[@]}"; do
        read -r workflow package <<<"$target"
        echo "echo '### $workflow: $package'"
        echo "echo '$package' | uv pip compile $UV_FLAGS -q - | sed 's/^/          /'"
    done
}

run_commands() {
    local commands
    commands="$(uv_commands)"
    if command -v uv >/dev/null 2>&1; then
        (cd "$ROOT" && bash -c "$commands")
        return
    fi
    docker run --rm --user "$(id -u):$(id -g)" -e HOME=/tmp -v "$ROOT":/work -w /work \
        "$DOCKER_IMAGE" bash -c "pip install -q --user uv && PATH=/tmp/.local/bin:\$PATH && $commands"
}

case "${1:-}" in
    -h|--help) usage; exit 0 ;;
    --list) [ $# -eq 1 ] || { usage >&2; exit 1; }; list_targets; exit 0 ;;
    "") ;;
    *) usage >&2; exit 1 ;;
esac

run_commands
