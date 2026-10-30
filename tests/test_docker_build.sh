#!/usr/bin/env bash
set -euo pipefail

ROOT="${DOCKER_BUILD_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
WORKFLOW="$ROOT/.github/workflows/infra-lint.yml"
SCRATCH=$(mktemp -d)
trap 'rm -rf "$SCRATCH"' EXIT

SCAN="$SCRATCH/docker-build.sh"
awk '
    /^  docker-build:$/ { in_job = 1; next }
    in_job && /^  [a-z][a-z-]*:$/ { exit }
    in_job && /^        run: \|$/ { inrun = 1; next }
    inrun && /^          / { sub(/^          /, ""); print; next }
    inrun && /^$/ { print ""; next }
    inrun { exit }
' "$WORKFLOW" > "$SCAN"

STUB_BIN="$SCRATCH/bin"
mkdir "$STUB_BIN"
cat > "$STUB_BIN/docker" <<'STUB'
#!/bin/sh
echo "$@" >> "$DOCKER_LOG"
for context; do :; done
[ -e "$context/BREAK" ] && exit 1
exit 0
STUB
chmod +x "$STUB_BIN/docker"

FAILED=0

if [ -s "$SCAN" ]; then
    echo "PASS: docker-build run block extracted from infra-lint.yml"
else
    echo "FAIL: no docker-build run block found in infra-lint.yml"
    exit 1
fi

if grep -A3 '^      enable_docker_build:$' "$WORKFLOW" | grep -q '^        default: false$'; then
    echo "PASS: enable_docker_build defaults to false"
else
    echo "FAIL: enable_docker_build does not default to false"
    FAILED=1
fi

new_repo() {
    local dir="$SCRATCH/$1"
    mkdir "$dir"
    git -C "$dir" init -q -b main
    git -C "$dir" config user.email t@t
    git -C "$dir" config user.name t
    echo "$dir"
}

base_here() {
    git -C "$1" add -A
    git -C "$1" commit -q -m base
    git -C "$1" update-ref refs/remotes/origin/main HEAD
    git -C "$1" checkout -q -b feature
}

change_here() {
    git -C "$1" add -A
    git -C "$1" commit -q -m change
}

expect_scan() {
    local expected="$1" name="$2" dir="$3" expected_calls="$4" contexts="${5:-}"
    local log="$dir.docker.log" out status=0
    rm -f "$log"
    : > "$log"
    out=$(cd "$dir" && PATH="$STUB_BIN:$PATH" DOCKER_LOG="$log" INPUT_BASE_REF=main \
        INPUT_DOCKER_CONTEXTS="$contexts" GITHUB_STEP_SUMMARY="$dir.summary" bash -e "$SCAN" 2>&1) || status=$?
    if [ "$status" -ne "$expected" ]; then
        echo "FAIL: $name (exit $status, wanted $expected)"
        echo "$out"
        FAILED=1
        return
    fi
    if [ "$(cat "$log")" != "$expected_calls" ]; then
        echo "FAIL: $name (docker calls: $(cat "$log" | tr '\n' '|'), wanted: $expected_calls)"
        FAILED=1
        return
    fi
    echo "PASS: $name"
}

dir=$(new_repo source-only-breaks)
mkdir -p "$dir/svc/src"
echo "FROM scratch" > "$dir/svc/Dockerfile"
touch "$dir/svc/BREAK"
echo "v1" > "$dir/svc/src/main.py"
base_here "$dir"
echo "v2" > "$dir/svc/src/main.py"
change_here "$dir"
expect_scan 1 "source file changed inside a context whose build fails fails the job" "$dir" \
    "build --file svc/Dockerfile svc"

dir=$(new_repo source-only-builds)
mkdir -p "$dir/svc/src"
echo "FROM scratch" > "$dir/svc/Dockerfile"
echo "v1" > "$dir/svc/src/main.py"
base_here "$dir"
echo "v2" > "$dir/svc/src/main.py"
change_here "$dir"
expect_scan 0 "source file changed inside a context whose build succeeds passes" "$dir" \
    "build --file svc/Dockerfile svc"

dir=$(new_repo other-dir)
mkdir -p "$dir/svc" "$dir/docs"
echo "FROM scratch" > "$dir/svc/Dockerfile"
touch "$dir/svc/BREAK"
echo "v1" > "$dir/docs/a.md"
base_here "$dir"
echo "v2" > "$dir/docs/a.md"
change_here "$dir"
expect_scan 0 "change outside every context builds nothing" "$dir" ""

dir=$(new_repo sibling-prefix)
mkdir -p "$dir/svc" "$dir/svc-other"
echo "FROM scratch" > "$dir/svc/Dockerfile"
touch "$dir/svc/BREAK"
echo "v1" > "$dir/svc-other/a.txt"
base_here "$dir"
echo "v2" > "$dir/svc-other/a.txt"
change_here "$dir"
expect_scan 0 "change in a sibling directory sharing the context name prefix builds nothing" "$dir" ""

dir=$(new_repo mapped-context)
mkdir -p "$dir/ci" "$dir/src"
echo "FROM scratch" > "$dir/ci/Dockerfile"
touch "$dir/BREAK"
echo "v1" > "$dir/src/lib.c"
base_here "$dir"
echo "v2" > "$dir/src/lib.c"
change_here "$dir"
expect_scan 1 "docker_contexts maps a Dockerfile to a wider context" "$dir" \
    "build --file ci/Dockerfile ." "ci/Dockerfile=."

dir=$(new_repo unmapped-context)
mkdir -p "$dir/ci" "$dir/src"
echo "FROM scratch" > "$dir/ci/Dockerfile"
touch "$dir/BREAK"
echo "v1" > "$dir/src/lib.c"
base_here "$dir"
echo "v2" > "$dir/src/lib.c"
change_here "$dir"
expect_scan 0 "without a mapping the context is the Dockerfile directory" "$dir" ""

dir=$(new_repo dockerfile-outside-context)
mkdir -p "$dir/ci" "$dir/app"
echo "FROM scratch" > "$dir/ci/Dockerfile"
base_here "$dir"
echo "FROM busybox" > "$dir/ci/Dockerfile"
change_here "$dir"
expect_scan 0 "changed Dockerfile outside its mapped context is built" "$dir" \
    "build --file ci/Dockerfile app" "ci/Dockerfile=app"

dir=$(new_repo two-images)
mkdir -p "$dir/a" "$dir/b"
echo "FROM scratch" > "$dir/a/Dockerfile"
echo "FROM scratch" > "$dir/b/Dockerfile"
touch "$dir/a/BREAK"
echo 1 > "$dir/a/f"
echo 1 > "$dir/b/f"
base_here "$dir"
echo 2 > "$dir/a/f"
echo 2 > "$dir/b/f"
change_here "$dir"
expect_scan 1 "a failing image does not stop the others from building" "$dir" \
    $'build --file a/Dockerfile a\nbuild --file b/Dockerfile b'

exit "$FAILED"
