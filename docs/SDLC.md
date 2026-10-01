# Software Development Lifecycle

Quality and security checks from developer workstation through merge. Post-merge, CodeQL, Infer and fuzz corpus runs are scheduled, and the trend dashboard runs weekly.

## Phase 1: Developer Workstation

Tools that run locally before code reaches CI.

### Pre-commit Hooks

Template: [`configs/.pre-commit-config.yaml`](https://github.com/PavelGuzenfeld/standard/blob/main/configs/.pre-commit-config.yaml)

| Hook | What it does |
|------|-------------|
| `clang-format` | Auto-formats C++ files on commit |
| `clang-tidy` | Static analysis with project `.clang-tidy` config |
| `cppcheck` | Bug and style checking |
| `trailing-whitespace` | Strips trailing whitespace |
| `end-of-file-fixer` | Ensures files end with newline |
| `check-yaml` | Validates YAML syntax |
| `check-added-large-files` | Blocks files > 500 KB |

Setup is in [Integration](INTEGRATION.md#7-pre-commit-hooks).

### Local Scripts

The `diff-*.sh` scripts run the CI checks on changed files. They are listed in the [README](https://github.com/PavelGuzenfeld/standard/blob/main/README.md#scripts). Run every C++ script and test inside the project's Docker dev container, never on the host.

`cppcheck` takes its suppressions from the environment: `CPPCHECK_SUPPRESS=cppcheck.suppress ./scripts/diff-cppcheck.sh origin/main`.

### CMake Presets for Sanitizer Builds

Template: [`configs/CMakePresets-sanitizers.json`](https://github.com/PavelGuzenfeld/standard/blob/main/configs/CMakePresets-sanitizers.json)

| Preset | Description |
|--------|------------|
| `debug-asan` | AddressSanitizer + UndefinedBehaviorSanitizer |
| `release-asan` | ASan/UBSan at -O2 — catches UB the optimizer exploits |
| `debug-tsan` | ThreadSanitizer (mutually exclusive with ASan) |
| `release-hardened` | `FORTIFY_SOURCE=3`, `_GLIBCXX_ASSERTIONS`, stack protector, CET |
| `debug` | Plain debug build |
| `release` | Plain optimized build |

```bash
cmake --preset debug-asan && cmake --build --preset debug-asan
ctest --test-dir build-asan --output-on-failure
```

### Compiler Warning Flags

Template: [`configs/cmake-warnings.cmake`](https://github.com/PavelGuzenfeld/standard/blob/main/configs/cmake-warnings.cmake)

Flags: `-Wall -Wextra -Wpedantic -Werror -Wshadow -Wnon-virtual-dtor -Wold-style-cast -Wconversion -Wsign-conversion -Wformat=2` plus GCC-specific extras (`-Wduplicated-cond`, `-Wlogical-op`).

## Phase 2: Pull Request Quality Gate

Automated checks that run on every PR. All must pass before merge.

### Diff-Aware Linting (C++)

Workflow: [`cpp-quality.yml`](https://github.com/PavelGuzenfeld/standard/blob/main/.github/workflows/cpp-quality.yml)

Changed files are found with `git diff --name-only --diff-filter=ACMR` against the base branch. Issues in untouched code never block PRs.

| Check | Tool | Workflow | Default |
|-------|------|----------|---------|
| Static analysis | clang-tidy | `cpp-quality.yml` (Docker) | Always |
| Bug/style checking | cppcheck | `cpp-quality.yml` (Docker) | Always |
| Code formatting | clang-format | `cpp-quality.yml` (Docker) | Opt-in |
| CWE lexical scan | flawfinder | `cpp-quality.yml` (Host) | Opt-in |
| Shell script linting | ShellCheck | `infra-lint.yml` (Host) | Opt-in |
| Dockerfile linting | Hadolint | `infra-lint.yml` (Host) | Opt-in |
| CMake file linting | cmake-lint | `infra-lint.yml` (Host) | Opt-in |
| Dangerous-workflow audit | custom script | `infra-lint.yml` (Host) | Opt-in |
| Binary-artifact scan | custom script | `infra-lint.yml` (Host) | Opt-in |
| Secrets detection | Gitleaks | `infra-lint.yml` (Host) | Opt-in |
| ASan + UBSan | sanitizer build | `cpp-quality.yml` (Docker) | Opt-in |
| Thread safety | TSan | `cpp-quality.yml` (Docker) | Opt-in |
| Code coverage | gcov/lcov + diff-cover | `cpp-quality.yml` (Docker) | Opt-in |
| Include analysis | IWYU | `cpp-quality.yml` (Docker) | Opt-in |
| Hardening verification | readelf (PIE, RELRO, NX, canary, CET) | `cpp-quality.yml` (Docker) | Opt-in |

The Workflow column shows where each check runs: in the caller's Docker image (their toolchain, headers and `compile_commands.json`) or on the host.

### Diff-Aware Linting (Python)

Workflow: [`python-quality.yml`](https://github.com/PavelGuzenfeld/standard/blob/main/.github/workflows/python-quality.yml)

| Check | Tool | Default |
|-------|------|---------|
| Lint (diff-aware) | ruff or flake8 via `diff-quality` | ruff |
| Tests | pytest with coverage | Always |
| Coverage (diff-aware) | diff-cover on changed lines | Always |

### Naming Conventions

| Check | What it enforces | Default |
|-------|-----------------|---------|
| File naming | `snake_case` for all file/directory names | Opt-in |
| Identifier naming | `snake_case` functions, `PascalCase` types (via clang-tidy) | Via config |

Built-in file naming exceptions: `CMakeLists.txt`, `Dockerfile`, `README.md`, `LICENSE`, dotfiles, `__init__.py`, `requirements*.txt`.

### Banned Patterns

| Check | What it bans | Rationale | Default |
|-------|-------------|-----------|---------|
| cout/printf ban | `std::cout`, `std::cerr`, `printf`, `fprintf`, `puts` | Use structured logging | Opt-in |
| new/delete ban | Raw `new`/`delete` (excludes `make_unique`, `make_shared`, operator overloads) | Use smart pointers | Opt-in |
| doctest enforcement | `gtest` macros, `#include <gtest/...>`, Google Benchmark | Use doctest + nanobench | Opt-in |

### PR Comments

Each workflow posts one summary comment, found again by a hidden marker and updated on later pushes.

| Workflow | Marker |
|----------|--------|
| C++ quality | `<!-- cpp-quality-report -->` |
| Python quality | `<!-- python-quality-report -->` |
| Python SAST | `<!-- python-sast-report -->` |
| Infrastructure lint | `<!-- infra-lint-report -->` |
| SBOM & supply chain | `<!-- sbom-report -->` |

Errors and warnings also appear as inline annotations on the PR diff.

## Phase 3: Security Scanning (SAST)

### Semgrep (Python)

Workflow: [`sast-python.yml`](https://github.com/PavelGuzenfeld/standard/blob/main/.github/workflows/sast-python.yml)

- Taint tracking for injection vulnerabilities
- OWASP Top 10 rule set
- SARIF results uploaded to GitHub Security tab
- Configurable rule sets

### CodeQL (C++ & Python)

Template: [`configs/ci-codeql.yml`](https://github.com/PavelGuzenfeld/standard/blob/main/configs/ci-codeql.yml)

- Inter-procedural taint tracking and data flow analysis
- Detects: buffer overflows, use-after-free, SQL/command injection, format strings, XSS, SSRF
- Free for public repositories

### Infer (C++)

Template: [`configs/ci-infer.yml`](https://github.com/PavelGuzenfeld/standard/blob/main/configs/ci-infer.yml)

| Checker | What it finds |
|---------|--------------|
| Pulse | Use-after-free, null deref, memory leaks, taint flows, unnecessary copies |
| InferBO | Buffer overflow at multiple severity levels |
| RacerD | Data races, lock ordering, thread safety violations |

RacerD covers thread safety, which matters for ROS2 executors and async callbacks.

### pip-audit (Python)

Workflow: [`sast-python.yml`](https://github.com/PavelGuzenfeld/standard/blob/main/.github/workflows/sast-python.yml)

- Checks `requirements.txt` against known CVE databases
- Uses `pypa/gh-action-pip-audit@v1.1.0`

## Phase 3b: SBOM & Supply Chain

Workflow: [`sbom.yml`](https://github.com/PavelGuzenfeld/standard/blob/main/.github/workflows/sbom.yml)

| Check | Tool | What it does |
|-------|------|-------------|
| Container SBOM | Syft | Scans Docker image for apt/pip/system packages |
| Source SBOM | Your script | Runs the script named by `source_sbom_script` as `python3 <script> --output source-sbom.cdx.json`. This repo ships none, so what it parses is up to you |
| Vulnerability scan | Grype | Scans merged SBOM against CVE databases |
| License check | Built-in checker or `license_check_script` | Checks the SBOMs against `license_policy_file` |

All artifacts (SPDX JSON, CycloneDX JSON, Grype report) are uploaded as GitHub Actions artifacts. Results are posted as a PR summary comment.

### Supply Chain Hygiene

Release provenance is in [Auto-Release](INTEGRATION.md#auto-release). Other checks:

| Check | Tool | What it does |
|-------|------|-------------|
| Dependency updates | Dependabot | Monitors GitHub Actions and pip ecosystems for outdated dependencies |
| Security policy | `SECURITY.md` | Defines vulnerability reporting process (OpenSSF Scorecard requirement) |

## Phase 4: Testing & Hardening

### Edge Case Checklist

Template: [`configs/test-checklist.md`](https://github.com/PavelGuzenfeld/standard/blob/main/configs/test-checklist.md)

It lists 11 mandatory categories, from empty inputs and boundaries to sanitizer passes under `debug-asan`, `debug-tsan` and `release-asan`, and a libFuzzer harness for parsing code.

### Multi-Compiler CI

Template: [`configs/ci-multi-compiler.yml`](https://github.com/PavelGuzenfeld/standard/blob/main/configs/ci-multi-compiler.yml)

- Matrix: GCC-13 + Clang-21
- ccache for fast rebuilds
- Multiple build modes (debug, release, sanitizers)

### Fuzzing

Template: [`configs/ci-fuzz.yml`](https://github.com/PavelGuzenfeld/standard/blob/main/configs/ci-fuzz.yml)

- ClusterFuzzLite through the reusable `fuzz.yml`, ASan by default
- Skipped with a notice when `.clusterfuzzlite/Dockerfile` is absent
- `code-change` mode on PRs, `batch` on the weekly schedule

Setup and a harness example: [Integration](INTEGRATION.md#9-fuzzing).

### Production Hardening

The `release-hardened` CMake preset enables:

| Flag | Purpose |
|------|---------|
| `_FORTIFY_SOURCE=3` | Runtime buffer overflow detection |
| `_GLIBCXX_ASSERTIONS` | Debug checks in libstdc++ containers |
| `-ftrivial-auto-var-init=zero` | Zero-initialize automatic variables |
| `-fstack-protector-strong` | Stack buffer overflow protection |
| `-fstack-clash-protection` | Stack clash protection |
| `-fcf-protection=full` | Intel CET (IBT + SHSTK), not CFI |
| `-fPIE` / `-pie` | Position Independent Executable (ASLR) |
| `-Wl,-z,relro,-z,now` | Full RELRO with immediate binding |

### Hardening Verification

The `hardening` job in `cpp-quality.yml` builds with the `release-hardened` preset (or a user script) and verifies the resulting ELF binaries using `readelf`:

| Property | How | Pass Condition |
|----------|-----|----------------|
| PIE | `readelf -h` | Type is `DYN` (shared libs skip — always DYN) |
| RELRO | `readelf -l` | `GNU_RELRO` segment present |
| Full RELRO | `readelf -d` | `BIND_NOW` in dynamic section |
| Stack canary | `readelf -s` | `__stack_chk_fail` symbol present |
| FORTIFY | `readelf -s` | `__*_chk` symbol present (warning only) |
| NX | `readelf -l` | `GNU_STACK` without execute flag |
| CET | `readelf -n` | `.note.gnu.property` with IBT + SHSTK (x86-64, from `-fcf-protection=full`) |

Standalone script: `scripts/check-hardening.sh <binary_path>...`
