#!/usr/bin/env bash
set -euo pipefail

OUTPUT="./AGENTS.md"
NON_INTERACTIVE=false


while [[ $# -gt 0 ]]; do
    case "$1" in
        --output)   OUTPUT="$2"; shift 2 ;;
        --non-interactive) NON_INTERACTIVE=true; shift ;;
        -h|--help)
            echo "Usage: $0 [--output PATH] [--non-interactive]"
            echo ""
            echo "  --output PATH        Write AGENTS.md to PATH (default: ./AGENTS.md)"
            echo "  --non-interactive    Accept all defaults from auto-detection"
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

detect_cpp=false
detect_python=false

[[ -f CMakeLists.txt || -f package.xml ]] && detect_cpp=true
[[ -f pyproject.toml || -f setup.py || -f requirements.txt ]] && detect_python=true

ask() {
    local prompt="$1" default="$2" var="$3"
    if $NON_INTERACTIVE; then
        eval "$var='$default'"
        return
    fi
    local yn
    if [[ "$default" == "y" ]]; then
        read -rp "$prompt [Y/n] " yn
        yn="${yn:-y}"
    else
        read -rp "$prompt [y/N] " yn
        yn="${yn:-n}"
    fi
    case "$yn" in
        [Yy]*) eval "$var=y" ;;
        *)     eval "$var=n" ;;
    esac
}

ask_choice() {
    local prompt="$1" default="$2" var="$3"
    if $NON_INTERACTIVE; then
        eval "$var='$default'"
        return
    fi
    local answer
    read -rp "$prompt [$default] " answer
    answer="${answer:-$default}"
    eval "$var='$answer'"
}

echo "=== AGENTS.md Generator ==="
echo ""
echo "Auto-detected:"
$detect_cpp    && echo "  C++    (found CMakeLists.txt / package.xml)"
$detect_python && echo "  Python (found pyproject.toml / setup.py / requirements.txt)"
$detect_cpp || $detect_python || echo "  (nothing detected — will ask)"
echo ""

cpp_default=n; $detect_cpp && cpp_default=y
py_default=n; $detect_python && py_default=y

ask "Enable C++ checks?" "$cpp_default" enable_cpp
ask "Enable Python checks?" "$py_default" enable_python

if [[ "$enable_cpp" == "n" && "$enable_python" == "n" ]]; then
    echo "Error: At least one language must be enabled."
    exit 1
fi

enable_clang_format=n
enable_file_naming=n
enable_ban_cout=n
enable_ban_new=n
enable_enforce_doctest=n
enable_flawfinder=n
enable_sanitizers=n
enable_tsan=n
enable_coverage=n
enable_iwyu=n
logger_replacement="RCLCPP_INFO"

if [[ "$enable_cpp" == "y" ]]; then
    echo ""
    echo "--- C++ opt-in checks ---"
    ask "  clang-format (C++23, 120-col, Allman)?" "n" enable_clang_format
    ask "  File naming enforcement (snake_case)?" "n" enable_file_naming
    ask "  Ban cout/printf (require structured logging)?" "n" enable_ban_cout
    if [[ "$enable_ban_cout" == "y" ]]; then
        ask_choice "  Logger replacement (RCLCPP_INFO / spdlog / custom)?" "RCLCPP_INFO" logger_replacement
    fi
    ask "  Ban raw new/delete (require smart pointers)?" "n" enable_ban_new
    ask "  Enforce doctest (ban gtest/gbenchmark)?" "n" enable_enforce_doctest
    ask "  Flawfinder CWE scanning?" "n" enable_flawfinder
    ask "  ASAN/UBSAN sanitizer tests?" "n" enable_sanitizers
    ask "  TSAN (ThreadSanitizer) tests?" "n" enable_tsan
    ask "  Code coverage reporting?" "n" enable_coverage
    ask "  Include-What-You-Use (IWYU)?" "n" enable_iwyu
fi

python_linter="ruff"
enable_semgrep=n
enable_pip_audit=n
enable_codeql=n

if [[ "$enable_python" == "y" ]]; then
    echo ""
    echo "--- Python options ---"
    ask_choice "  Linter (ruff / flake8)?" "ruff" python_linter
    ask "  Semgrep SAST?" "n" enable_semgrep
    ask "  pip-audit CVE scanning?" "n" enable_pip_audit
    ask "  CodeQL deep analysis?" "n" enable_codeql
fi

enable_shellcheck=n
enable_hadolint=n
enable_cmake_lint=n

echo ""
echo "--- Infrastructure lint ---"
ask "  ShellCheck (shell scripts)?" "n" enable_shellcheck
ask "  Hadolint (Dockerfiles)?" "n" enable_hadolint
if [[ "$enable_cpp" == "y" ]]; then
    ask "  cmake-lint (CMake files)?" "n" enable_cmake_lint
fi

TEMPLATE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/configs/AGENTS.md"

enabled=""
for flag in cpp python clang_format file_naming ban_cout ban_new enforce_doctest flawfinder \
            sanitizers tsan coverage iwyu semgrep pip_audit codeql shellcheck hadolint cmake_lint; do
    var="enable_$flag"
    [[ "${!var}" == "y" ]] && enabled+=" $flag"
done
[[ "$enable_ban_cout" == "y" || "$enable_ban_new" == "y" || "$enable_enforce_doctest" == "y" ]] && enabled+=" any_ban"
[[ "$enable_sanitizers" == "y" || "$enable_tsan" == "y" ]] && enabled+=" any_sanitizer"

FILTER_RULES='S@^### Always Enforced$@cpp
S@^## C\+\+ Conventions$@cpp
S@^### File and Directory Naming$@file_naming
S@^### Banned Patterns$@any_ban
S@^## Testing Requirements$@cpp
S@^### Sanitizer Build Presets$@any_sanitizer
S@^### Python \(if applicable\)$@python
S@^## Python Conventions$@python
S@^### Adding File Naming Exceptions$@file_naming
S@^### Suppressing cppcheck Warnings$@cpp
S@^### Overriding clang-tidy Checks$@cpp
L@^> @never
L@^- \*\*clang-format\*\*@clang_format
L@^- \*\*File naming\*\*@file_naming
L@^- \*\*Banned: cout@ban_cout
L@^- \*\*Banned: raw new@ban_new
L@^- \*\*Banned: gtest@enforce_doctest
L@^- \*\*Flawfinder\*\*@flawfinder
L@^- \*\*Coverage\*\* — gcov@coverage
L@^- \*\*IWYU\*\*@iwyu
L@^- \*\*Hardening verification\*\*@never
L@^- \*\*Identifier naming\*\*@cpp
L@^\| `std::cout`@ban_cout
L@^\| `new T`@ban_new
L@^\| `#include <(gtest|benchmark)/@enforce_doctest
L@^[0-9]+\. \*\*ASan@sanitizers
L@^[0-9]+\. \*\*TSan@tsan
L@^[0-9]+\. \*\*Release \+ sanitizers@sanitizers
L@^cmake --preset debug-asan@sanitizers
L@^cmake --preset debug-tsan@tsan
L@^cmake --preset release-asan@sanitizers
L@^cmake --preset release-hardened@never
L@^All C\+\+ checks and tests@cpp
L@^\./scripts/diff-(clang-tidy|cppcheck|test-mirror)@cpp
L@^\./scripts/diff-clang-format@clang_format
L@^\./scripts/diff-file-naming@file_naming
L@^\./scripts/diff-iwyu@iwyu
L@^(ruff check|pytest)@python
L@^- \*\*C\+\+\*\*:@cpp
L@^- \*\*Python\*\*:@python
C@- **SAST** — @Semgrep:semgrep;pip-audit:pip_audit;CodeQL:codeql
C@Static analysis: @Semgrep:semgrep;pip-audit:pip_audit;CodeQL:codeql
C@  - Linting (ruff/flake8), @Semgrep:semgrep;pip-audit:pip_audit;CodeQL:codeql
C@  - Opt-in: @clang-format:clang_format;file naming:file_naming;banned patterns:any_ban
C@- `infra-lint.yml` — @ShellCheck:shellcheck;Hadolint:hadolint;cmake-lint:cmake_lint'

filter_template() {
    awk -v enabled="$enabled" '
    BEGIN {
        n = split(enabled, names, " ")
        for (i = 1; i <= n; i++) on[names[i]] = 1
    }
    FNR == NR {
        split($0, f, "@")
        kind[++rules] = f[1]; pattern[rules] = f[2]; arg[rules] = f[3]
        next
    }
    function emit(text) {
        if (pending_blank && printed && !after_open) print ""
        print text
        pending_blank = 0; printed = 1; after_open = 0
    }
    function flush_headings(   level) {
        for (level = 1; level <= 4; level++) {
            if (level in heading) { emit(heading[level]); pending_blank = 1; delete heading[level] }
        }
    }
    function keep_items(text, prefix, mapping,   rest, count, items, i, j, pairs, kv, keep, out) {
        rest = substr(text, length(prefix) + 1)
        count = split(rest, items, ", ")
        split(mapping, pairs, ";")
        for (i = 1; i <= count; i++) {
            keep = 1
            for (j in pairs) {
                split(pairs[j], kv, ":")
                if (index(items[i], kv[1]) == 1 && !on[kv[2]]) keep = 0
            }
            if (keep) out = out (out == "" ? "" : ", ") items[i]
        }
        return out == "" ? "" : prefix out
    }
    {
        line = $0
        is_fence = line ~ /^```/
        if (is_fence) in_fence = !in_fence
        if (!in_fence && !is_fence && line ~ /^#+ /) {
            match(line, /^#+/); level = RLENGTH
            if (skipping && level <= skip_level) skipping = 0
            for (r = 1; r <= rules && !skipping; r++) {
                if (kind[r] == "S" && line ~ pattern[r] && !on[arg[r]]) { skipping = 1; skip_level = level }
            }
            if (skipping) next
            heading[level] = line
            for (d = level + 1; d <= 4; d++) delete heading[d]
            item_number = 0
            next
        }
        if (skipping) next
        if (line == "") { pending_blank = 1; drop_children = 0; next }
        if (drop_children && line ~ /^[ \t]+-/) next
        drop_children = 0
        dropped = 0
        for (r = 1; r <= rules; r++) {
            if (kind[r] == "L" && line ~ pattern[r] && !on[arg[r]]) dropped = 1
            if (kind[r] == "C" && index(line, pattern[r]) == 1) {
                line = keep_items(line, pattern[r], arg[r])
                if (line == "") dropped = 1
            }
        }
        if (dropped) { drop_children = 1; next }
        if (line ~ /^[0-9]+\. /) sub(/^[0-9]+/, ++item_number, line); else item_number = 0
        if (is_fence && !in_fence) pending_blank = 0
        flush_headings()
        emit(line)
        if (is_fence && in_fence) after_open = 1
    }' <(printf '%s\n' "$FILTER_RULES") "$TEMPLATE"
}

escape_sed() { printf '%s' "$1" | sed 's/[\\&|]/\\&/g'; }

flake8_edits=()
[[ "$python_linter" == "ruff" ]] || flake8_edits=(-e 's/format with ruff format or black/format with black/' -e 's/^ruff check /flake8 /')

filter_template | sed \
    -e "s|ruff (or flake8)|$(escape_sed "$python_linter")|" \
    -e "s|ruff (preferred) or flake8|$(escape_sed "$python_linter")|" \
    -e "s|ruff/flake8|$(escape_sed "$python_linter")|" \
    -e "s|\`RCLCPP_INFO\`|\`$(escape_sed "$logger_replacement")\`|" \
    "${flake8_edits[@]}" > "$OUTPUT"

echo ""
echo "=== Generated: $OUTPUT ==="
echo ""
echo "Included sections:"
[[ "$enable_cpp" == "y" ]]              && echo "  - C++ quality (clang-tidy, cppcheck — always on)"
[[ "$enable_clang_format" == "y" ]]     && echo "  - clang-format"
[[ "$enable_file_naming" == "y" ]]      && echo "  - File naming (snake_case)"
[[ "$enable_ban_cout" == "y" ]]         && echo "  - Ban cout/printf (logger: $logger_replacement)"
[[ "$enable_ban_new" == "y" ]]          && echo "  - Ban raw new/delete"
[[ "$enable_enforce_doctest" == "y" ]]  && echo "  - Enforce doctest"
[[ "$enable_flawfinder" == "y" ]]       && echo "  - Flawfinder"
[[ "$enable_sanitizers" == "y" ]]       && echo "  - ASAN/UBSAN"
[[ "$enable_tsan" == "y" ]]            && echo "  - TSAN"
[[ "$enable_coverage" == "y" ]]         && echo "  - Coverage"
[[ "$enable_iwyu" == "y" ]]             && echo "  - IWYU"
[[ "$enable_python" == "y" ]]           && echo "  - Python quality ($python_linter)"
[[ "$enable_semgrep" == "y" ]]          && echo "  - Semgrep"
[[ "$enable_pip_audit" == "y" ]]        && echo "  - pip-audit"
[[ "$enable_codeql" == "y" ]]           && echo "  - CodeQL"
[[ "$enable_shellcheck" == "y" ]]       && echo "  - ShellCheck"
[[ "$enable_hadolint" == "y" ]]         && echo "  - Hadolint"
[[ "$enable_cmake_lint" == "y" ]]       && echo "  - cmake-lint"
echo ""
echo "Next steps:"
echo "  1. Review $OUTPUT"
echo "  2. Set up .github/workflows/ to call the reusable workflows"
echo "  3. See INTEGRATION.md for full workflow setup"
