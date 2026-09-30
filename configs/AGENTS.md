# Agent Instructions — Quality Standard

> Copy this file to your repo root as `AGENTS.md`.
> It tells AI agents what your quality gates enforce so they write compliant code from the start.

## Quality Standard

This project uses [diff-aware quality workflows](https://github.com/PavelGuzenfeld/standard) for CI.
Only changed files are checked — but all new and modified code must pass.

### Always Enforced

- **clang-tidy** — clang-analyzer, cppcoreguidelines, modernize, bugprone, performance, readability
- **cppcheck** — bug and style checking with project-specific suppressions

### Opt-in (enabled in this project)

> Remove items below that your project has not enabled.

- **clang-format** — 120-column, 4-space indent, Allman braces
- **File naming** — snake_case for all files and directories
- **Banned: cout/printf** — use structured logging instead
- **Banned: raw new/delete** — use smart pointers (`std::make_unique`, `std::make_shared`)
- **Banned: gtest/gbenchmark** — use doctest and nanobench
- **Hardening verification** — PIE, RELRO, stack canary, NX checks on release binaries
- **Identifier naming** — snake_case functions/variables, PascalCase types, trailing `_` for private members

### Python (if applicable)

- **Linting** — ruff (or flake8) on changed lines, zero violations required
- **Coverage** — pytest + diff-cover, minimum score on changed lines
- **SAST** — Semgrep (OWASP Top 10), pip-audit (CVE scanning)

## C++ Conventions

### File and Directory Naming

All files and directories are `snake_case`: lowercase letters, digits, underscores.

Valid: `flight_controller.cpp`, `nav_utils/`, `terrain_map.hpp`
Invalid: `FlightController.cpp`, `NavUtils/`, `terrainMap.hpp`

**Built-in exemptions** (no config needed):
`CMakeLists.txt`, `Dockerfile`, `README.md`, `LICENSE`, `CHANGELOG.md`, ALL-CAPS markdown files (`AGENTS.md`, `SECURITY.md`),
dotfiles (`.clang-tidy`, `.gitignore`), `__init__.py`, `requirements*.txt`

**Package directories**: `include/<package_name>/` must also be snake_case.

### Identifier Naming

| Element | Convention | Example |
|---------|-----------|---------|
| Functions / methods | `snake_case` | `compute_heading()` |
| Variables / parameters | `snake_case` | `max_altitude` |
| Types / classes / structs | `PascalCase` | `FlightController` |
| Private members | `snake_case_` (trailing underscore) | `config_`, `state_` |
| Constants | `UPPER_CASE` | `MAX_RETRIES` |
| Enum constants | `PascalCase` | `Idle`, `Armed` |
| Namespaces | `snake_case` | `nav_utils` |

### Include Convention

Use `#pragma once`, not `#ifndef` guards. Include standard library headers first, then project headers (`"project/package_header.hpp"`). Minimize includes and forward-declare where possible.

### Banned Patterns

| Pattern | Reason | Alternative |
|---------|--------|-------------|
| `std::cout`, `std::cerr`, `printf`, `fprintf`, `puts` | No structured logging | Use your project's logger (e.g., `RCLCPP_INFO`) |
| `new T`, `delete p` | Memory leaks | `std::make_unique<T>()`, `std::make_shared<T>()` |
| `#include <gtest/gtest.h>` | Non-standard for this project | `#include <doctest/doctest.h>` |
| `#include <benchmark/benchmark.h>` | Non-standard for this project | `#include <nanobench.h>` |

The bans apply to production code only. Test files (`test` in the path) may follow different rules.

## Testing Requirements

### Mandatory Test Categories

Every non-trivial module should cover these edge cases:

1. **Empty inputs** — empty containers, null optionals, zero-length spans
2. **Boundary conditions** — off-by-one, min/max values, INT_MAX, epsilon
3. **Single-element** — containers with one item
4. **Invalid inputs** — out-of-range, malformed strings, type mismatches
5. **Resource exhaustion** — allocation failure, full queues, disk full
6. **Concurrent access** — data races, deadlocks, torn reads (if applicable)
7. **Performance baselines** — nanobench for critical paths
8. **ASan + UBSan** — build and test with address/undefined sanitizers
9. **TSan** — build and test with thread sanitizer (if multi-threaded)
10. **Release + sanitizers** — verify optimized builds don't introduce UB
11. **Fuzz harness** — libFuzzer for parsers, serializers, and input handlers

### Sanitizer Build Presets

```bash
cmake --preset debug-asan       # ASan + UBSan
cmake --preset debug-tsan       # ThreadSanitizer
cmake --preset release-asan     # ASan + UBSan at -O2
cmake --preset release-hardened # Production hardening (FORTIFY, PIE, RELRO)
```

## Python Conventions

Lint with ruff (preferred) or flake8, format with ruff format or black, test with pytest, cover changed lines with diff-cover, run Semgrep and pip-audit, follow PEP 8, and use type hints.

## Local Verification

All C++ checks and tests run inside the project's Docker dev container, never on the host. The image holds every dependency needed to reproduce CI: compilers, clang-tidy, cppcheck, clang-format, cmake, project libraries and headers.

```bash
./scripts/diff-clang-tidy.sh origin/main build "cpp hpp h"
./scripts/diff-cppcheck.sh origin/main
./scripts/diff-clang-format.sh origin/main "cpp hpp h"
./scripts/diff-file-naming.sh origin/main naming-exceptions.txt
./scripts/diff-iwyu.sh origin/main build
./scripts/diff-test-mirror.sh origin/main

ruff check src/ tests/
pytest --cov=src tests/
```

Setup generators (`generate-workflow.sh`, `install-hooks.sh`, `generate-baseline.sh`, `generate-badges.sh`) are listed in the [standard README](https://github.com/PavelGuzenfeld/standard#scripts).

## Customization

### Adding File Naming Exceptions

Create or edit `naming-exceptions.txt`, one regex per line (for example `vendor`, `third_party`, `.*_generated`), and pass it to the workflow:

```yaml
with:
  file_naming_exceptions: naming-exceptions.txt
```

### Suppressing cppcheck Warnings

Add to `cppcheck.suppress`:

```
unusedFunction:src/legacy_module.cpp
shadowVariable
```

The first line suppresses one check in one file. The second suppresses it globally.

### Overriding clang-tidy Checks

Edit `.clang-tidy` in your repo root. CI uses it when present. To disable a check:

```yaml
Checks: >-
  ...,
  -modernize-use-trailing-return-type
```

## CI Workflows

Every project integrating this standard must have a quality workflow in `.github/workflows/`.

### Required Workflows

- **C++**: `cpp-quality.yml` calling the reusable workflow
  - Required input: `docker_image` (`compile_commands_path` defaults to `build`)
  - Always enabled: clang-tidy, cppcheck
  - Opt-in: clang-format, file naming, banned patterns, identifier naming
- **Python**: `python-quality.yml` + `sast-python.yml`
  - Linting (ruff/flake8), pytest + diff-cover, Semgrep, pip-audit

### Optional Workflows

- `ci-codeql.yml` — CodeQL analysis
- `ci-infer.yml` — Facebook Infer static analysis (C++)
- `ci-fuzz.yml` — libFuzzer continuous fuzzing with corpus caching
- `ci-multi-compiler.yml` — GCC + Clang multi-compiler builds
- `infra-lint.yml` — ShellCheck, Hadolint, cmake-lint, dangerous-workflow audit, binary-artifact scan
- `sbom.yml` — Syft container SBOM, Grype vulnerability scanning, license check
- `auto-release.yml` — Conventional-commit version bumps, GitHub Releases, SLSA provenance

Full setup instructions: see `INTEGRATION.md`.

## Security Hygiene

- **SECURITY.md** — must exist at repo root with vulnerability reporting instructions
- **Dependabot** — `.github/dependabot.yml` monitors dependency updates (GitHub Actions, pip, etc.)
- **SLSA provenance** — opt-in attestation on releases via `auto-release.yml` with `enable_provenance: true`

## Git & PR Rules

- **No AI attribution** — never add "Generated with Claude Code", "Co-Authored-By", or similar AI-generated footers to commit messages, PR descriptions, or any content
- **Conventional commits** — use `feat:`, `fix:`, `feat!:`, `BREAKING CHANGE:` prefixes (drives auto-release versioning)
- **Versioning** — first release is always `v0.0.1`, see `docs/VERSIONING.md`
