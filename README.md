# Standard

[![Release](https://img.shields.io/github/v/release/PavelGuzenfeld/standard?label=version&color=blue&style=flat)](https://github.com/PavelGuzenfeld/standard/releases)
[![OpenSSF Scorecard](https://api.scorecard.dev/projects/github.com/PavelGuzenfeld/standard/badge)](https://scorecard.dev/viewer/?uri=github.com/PavelGuzenfeld/standard)
[![OpenSSF Best Practices](https://www.bestpractices.dev/projects/12012/badge)](https://www.bestpractices.dev/projects/12012)

Reusable GitHub Actions for C++ and Python quality gates. Only files changed in the PR are checked, so legacy code never blocks a merge.

C++ tools run inside your Docker image, so they see your toolchain, headers and `compile_commands.json`. Each workflow posts one summary comment on the PR and updates it on every push.

## Quick Start

C++:

```yaml
name: Quality
on:
  pull_request:
    branches: [main]

jobs:
  cpp:
    uses: PavelGuzenfeld/standard/.github/workflows/cpp-quality.yml@main
    with:
      docker_image: ghcr.io/your-org/your-dev-image:latest
    permissions:
      contents: read
      pull-requests: write
```

clang-tidy and cppcheck run by default. Everything else is opt-in.

Python:

```yaml
jobs:
  python:
    uses: PavelGuzenfeld/standard/.github/workflows/python-quality.yml@main
    permissions:
      contents: read
      pull-requests: write

  sast:
    uses: PavelGuzenfeld/standard/.github/workflows/sast-python.yml@main
    permissions:
      contents: read
      pull-requests: write
      security-events: write
```

To generate these files instead, see the [Consumer Quickstart](docs/CONSUMER-QUICKSTART.md).

## Documentation

The full site is at <https://pavelguzenfeld.com/standard/>. The same pages live in `docs/`:

| Document | Content |
|----------|---------|
| [Integration Guide](docs/INTEGRATION.md) | Setup for C++ and Python projects |
| [SDLC](docs/SDLC.md) | Pre-commit, PR gates, SAST, testing, hardening |
| [Versioning](docs/VERSIONING.md) | SemVer rules and git tags |
| [Consumer Quickstart](docs/CONSUMER-QUICKSTART.md) | `standard-ci` presets |
| [Compliance](docs/COMPLIANCE.md) | Org-wide drift updates and CIS scans |
| [Conventions](docs/conventions.md) | Coding conventions, PR gate, scan commands |

## Reusable Workflows

| Workflow | Checks |
|----------|--------|
| [`cpp-quality.yml`](.github/workflows/cpp-quality.yml) | clang-tidy, cppcheck, clang-format, flawfinder, ASan/UBSan, TSan, coverage, IWYU, hardening, file naming, banned patterns |
| [`infra-lint.yml`](.github/workflows/infra-lint.yml) | ShellCheck, Hadolint, cmake-lint, dangerous-workflow audit, binary-artifact scan, Gitleaks |
| [`python-quality.yml`](.github/workflows/python-quality.yml) | ruff/flake8, pytest, diff-cover |
| [`sast-python.yml`](.github/workflows/sast-python.yml) | Semgrep, pip-audit, CodeQL |
| [`sbom.yml`](.github/workflows/sbom.yml) | Syft container SBOM, source dependency scan, Grype, license check |
| [`version-check.yml`](.github/workflows/version-check.yml) | SemVer in package.xml, CMakeLists.txt, pyproject.toml |
| [`auto-release.yml`](.github/workflows/auto-release.yml) | Conventional-commit version bump, git tag, GitHub Release, SLSA provenance |
| [`trend-dashboard.yml`](.github/workflows/trend-dashboard.yml) | Weekly pass-rate report, optional Slack and Discussions posting |
| [`version-sync.yml`](.github/workflows/version-sync.yml) | Sync opt-in version files (CMakeLists.txt, pyproject.toml, package.xml, package.json, `GIT_TAG` in a caller's README) to a release tag; this repo enables only pyproject.toml |
| [`cis-compliance.yml`](.github/workflows/cis-compliance.yml) | CIS supply-chain scan of one repo |
| [`cis-org-compliance.yml`](.github/workflows/cis-org-compliance.yml) | CIS supply-chain scan across an org |
| [`compliance.yml`](.github/workflows/compliance.yml) | Scan an org for standard-ci drift, optionally open update PRs |
| [`install-test.yml`](.github/workflows/install-test.yml) | Install the package and check `find_package` from a consumer |
| [`pre-commit.yml`](.github/workflows/pre-commit.yml) | Run pre-commit hooks in CI |
| [`scheduled-health.yml`](.github/workflows/scheduled-health.yml) | Open an issue when a scheduled upstream workflow fails |
| [`release.yml`](.github/workflows/release.yml) | This repo only: triggers auto-release and version-sync on push to main |

Composite actions for single steps live in `actions/`: `diff-files`, `clang-tidy`, `cppcheck`, `clang-format`, `ruff-check`, `shellcheck`, `gitleaks`, `gdlint`, `ts-naming`, `layering`. Use one as `PavelGuzenfeld/standard/actions/<name>@<sha>`. `ruff-check` and the ruff mode of `python-quality` need a diff-cover that lists the `ruff.check` driver; Python 3.8 cannot install one (diff-cover 9.2.0 has none).

## Workflow Inputs

<details>
<summary><strong>C++ Inputs</strong></summary>

**Core:**

| Input | Default | Description |
|-------|---------|-------------|
| `docker_image` | *required* | Docker image with clang-tidy, cppcheck, and compile_commands.json |
| `compile_commands_path` | `build` | Path to compile_commands.json inside the container |
| `source_mount` | `/workspace/src` | Where repo source is mounted inside the container |
| `source_setup` | `''` | Shell command to source before tools (e.g., ROS2 setup.bash) |
| `runner` | `"ubuntu-latest"` | Runner labels as a JSON string or array |
| `file_extensions` | `cpp hpp h cc cxx` | Space-separated C++ file extensions to check |
| `exclude_file` | `''` | Path to file listing excluded paths (one per line, `#` comments) |
| `pre_analysis_script` | `''` | Script to run inside Docker before analysis |
| `build_cache_key` | `''` | Cache key for build artifacts (empty = no caching) |
| `build_cache_paths` | `build install` | Space-separated paths to cache |
| `checkout_submodules` | `false` | Pass to actions/checkout submodules (false, true, recursive) |
| `select_jobs` | `all` | Comma-separated jobs to run (all, clang-tidy, cppcheck, coverage, tsan, sanitizers, iwyu, clang-format, doctest, file-naming, cout-ban, new-delete-ban, flawfinder, hardening) |
| `base_ref` | `''` | Base branch for diff (fallback when github.base_ref is empty) |

**clang-tidy:**

| Input | Default | Description |
|-------|---------|-------------|
| `enable_clang_tidy` | `true` | Enable clang-tidy analysis |
| `clang_tidy_config` | `''` | Path to .clang-tidy config (empty = use repo default) |
| `clang_tidy_jobs` | `4` | Parallel clang-tidy jobs inside Docker |

**cppcheck:**

| Input | Default | Description |
|-------|---------|-------------|
| `enable_cppcheck` | `true` | Enable cppcheck analysis |
| `cppcheck_suppress` | `''` | Path to cppcheck suppressions file |
| `cppcheck_includes` | `''` | Space-separated include directories |
| `cppcheck_include_file` | `''` | Path to file containing include dirs (one per line) |
| `cppcheck_std` | `c++23` | C++ standard for cppcheck |
| `cppcheck_inconclusive` | `false` | Enable --inconclusive mode (may produce false positives) |
| `cppcheck_strict` | `false` | Use --error-exitcode=1 for native cppcheck error handling |

**clang-format:**

| Input | Default | Description |
|-------|---------|-------------|
| `enable_clang_format` | `false` | Enable clang-format check (opt-in) |
| `clang_format_config` | `''` | Path to .clang-format config |

**Flawfinder:**

| Input | Default | Description |
|-------|---------|-------------|
| `enable_flawfinder` | `false` | Enable flawfinder CWE lexical scan (opt-in) |
| `flawfinder_min_level` | `2` | Minimum flawfinder finding level (1-5) |
| `enable_sarif` | `false` | Upload SARIF to GitHub Security tab |

**Sanitizers (ASan/UBSan):**

| Input | Default | Description |
|-------|---------|-------------|
| `enable_sanitizers` | `false` | Enable ASan/UBSan test job (opt-in) |
| `sanitizer_script` | `''` | Script to build+test with sanitizers |
| `sanitizer_suppressions` | `''` | Path to LSAN suppressions file |
| `sanitizer_packages` | `''` | Space-separated packages to test (empty = all) |

**ThreadSanitizer:**

| Input | Default | Description |
|-------|---------|-------------|
| `enable_tsan` | `false` | Enable TSan test job (opt-in, mutually exclusive with ASan) |
| `tsan_script` | `''` | Script to build+test with TSan |
| `tsan_suppressions` | `''` | Path to TSan suppressions file |
| `tsan_packages` | `''` | Space-separated packages to test with TSan (empty = all) |

**Coverage:**

| Input | Default | Description |
|-------|---------|-------------|
| `enable_coverage` | `false` | Enable gcov/lcov coverage reporting (opt-in) |
| `coverage_script` | `''` | Script to build+test with coverage and collect lcov |
| `coverage_packages` | `''` | Space-separated packages to measure (empty = all) |
| `coverage_threshold` | `0` | Minimum overall line coverage % (0 = no threshold) |
| `coverage_diff_threshold` | `0` | Minimum coverage % for changed lines via diff-cover (0 = disabled) |
| `coverage_diff_report` | `false` | Generate diff-cover markdown report as artifact |

**Hardening:**

| Input | Default | Description |
|-------|---------|-------------|
| `enable_hardening` | `false` | Enable binary hardening verification (opt-in) |
| `hardening_script` | `''` | Script to build with hardening flags |
| `hardening_binary_paths` | `build-hardened/bin/*` | Space-separated globs to ELF binaries to check |
| `hardening_skip_checks` | `''` | Space-separated checks to skip: pie relro bindnow canary fortify nx cet |

**IWYU:**

| Input | Default | Description |
|-------|---------|-------------|
| `enable_iwyu` | `false` | Enable Include-What-You-Use analysis (opt-in) |
| `iwyu_script` | `''` | Script to run IWYU analysis |
| `iwyu_mapping_file` | `''` | Path to IWYU mapping file (.imp) |

**Naming & Banned Patterns:**

| Input | Default | Description |
|-------|---------|-------------|
| `enable_file_naming` | `false` | Enable snake_case file naming check (opt-in) |
| `file_naming_exceptions` | `''` | Path to naming exception regexes |
| `file_naming_allowed_prefixes` | `_` | Allowed prefixes for file names |
| `enforce_doctest` | `false` | Require doctest instead of gtest (opt-in) |
| `test_file_pattern` | `test` | Grep pattern to identify test files |
| `ban_cout` | `false` | Ban cout/cerr/printf in non-test files (opt-in) |
| `ban_new` | `false` | Ban raw new/delete in non-test files (opt-in) |

**jscpd:**

| Input | Default | Description |
|-------|---------|-------------|
| `enable_jscpd` | `false` | Enable jscpd copy-paste detection on changed files (opt-in) |
| `jscpd_threshold` | `5` | Maximum duplicated lines in percent before jscpd flags the changed files |
| `jscpd_report_only` | `true` | Report duplication as a warning without failing the job |

</details>

<details>
<summary><strong>Infra Lint Inputs</strong></summary>

| Input | Default | Description |
|-------|---------|-------------|
| `enable_cmake_lint` | `false` | Enable cmake-lint for CMake files (opt-in) |
| `cmake_lint_config` | `''` | Path to .cmake-format.yaml config file |
| `enable_dangerous_workflows` | `false` | Enable dangerous-workflow pattern audit (opt-in) |
| `enable_binary_artifacts` | `false` | Enable binary artifact detection in PRs (opt-in) |
| `enable_gitleaks` | `false` | Enable Gitleaks secrets detection (opt-in) |
| `gitleaks_config` | `''` | Path to .gitleaks.toml config file |
| `exclude_file` | `''` | Path to file listing excluded paths (one per line, `#` comments) |
| `base_ref` | `''` | Base branch for diff |
| `runner` | `"ubuntu-latest"` | Runner labels as a JSON string or array |
| `select_jobs` | `all` | Comma-separated jobs to run (all, cmake-lint, dangerous-workflows, binary-artifacts, gitleaks) |

</details>

<details>
<summary><strong>Python Inputs</strong></summary>

| Input | Default | Description |
|-------|---------|-------------|
| `python_version` | `3.12` | Python version to use |
| `target_python` | `py38` | Target Python version for ruff |
| `python_linter` | `ruff` | Linter: `ruff` or `flake8` |
| `source_dirs` | `src` | Source directories |
| `test_dirs` | `tests` | Test directories |
| `ruff_version` | `0.16.5` | Ruff version to install |
| `diff_cover_version` | `10.5.1` | diff-cover version to install. The ruff step needs a diff-cover that lists the `ruff.check` driver, which Python 3.8 cannot install (diff-cover 9.2.0 has none) |
| `ruff_select` | `E,W,F,I,N` | Ruff rule selection. Overrides `select` and `ignore` in pyproject.toml; drop `E` to skip E501 line-length errors |
| `enable_tests` | `true` | Run pytest and collect coverage (disable for projects with external test deps like ROS2) |
| `base_ref` | `''` | Base branch for diff comparison (falls back to github.base_ref, then main) |
| `fail_under` | `100` | Minimum diff-quality score (0-100) |
| `runner` | `"ubuntu-latest"` | Runner labels as a JSON string or array |

</details>

<details>
<summary><strong>Python SAST Inputs</strong></summary>

| Input | Default | Description |
|-------|---------|-------------|
| `python_version` | `3.12` | Python version to use |
| `enable_semgrep` | `true` | Enable Semgrep security scanning |
| `semgrep_version` | `1.150.0` | Semgrep Docker image version (pin to avoid breaking changes) |
| `semgrep_rules` | `p/python p/owasp-top-ten` | Semgrep rule sets |
| `enable_pip_audit` | `true` | Enable pip-audit CVE scanning |
| `requirements_file` | `requirements.txt` | Path to requirements file |
| `enable_codeql` | `false` | Enable CodeQL (free for public repos) |
| `codeql_queries` | `security-extended` | CodeQL query suite |
| `enable_code_scanning` | `true` | Upload SARIF to code scanning (set `false` on a private repo without Advanced Security) |
| `runner` | `"ubuntu-latest"` | Runner labels as a JSON string or array |

</details>

<details>
<summary><strong>SBOM Inputs</strong></summary>

| Input | Default | Description |
|-------|---------|-------------|
| `docker_image` | *required* | Docker image to scan |
| `source_sbom_script` | `''` | Path to source-level SBOM generation script (empty = skip) |
| `grype_fail_on` | `''` | Fail on severity: "" = report-only, "critical", "high", "medium", "low" |
| `grype_ignore_file` | `''` | Path to .grype.yaml ignore file |
| `checkout_submodules` | `false` | Checkout submodules for source SBOM (true/false/recursive) |
| `license_policy_file` | `''` | Path to license policy YAML (empty = skip license check) |
| `license_check_script` | `''` | Path to license check Python script in caller repo |
| `enable_code_scanning` | `true` | Upload SARIF to code scanning (set `false` on a private repo without Advanced Security) |
| `runner` | `"ubuntu-latest"` | Runner labels as a JSON string or array |

</details>

<details>
<summary><strong>Version Check Inputs</strong></summary>

| Input | Default | Description |
|-------|---------|-------------|
| `exclude_file` | `''` | Path to file listing excluded paths (one per line, `#` comments) |
| `base_ref` | `''` | Base branch for diff (fallback when github.base_ref is empty) |
| `runner` | `"ubuntu-latest"` | Runner labels as a JSON string or array |

</details>

<details>
<summary><strong>Auto-Release Inputs</strong></summary>

| Input | Default | Description |
|-------|---------|-------------|
| `default_bump` | `patch` | Default bump when no conventional commit prefix detected |
| `enable_provenance` | `false` | Enable SLSA provenance attestation for releases (opt-in) |

</details>

<details>
<summary><strong>Trend Dashboard Inputs</strong></summary>

| Input | Default | Description |
|-------|---------|-------------|
| `lookback_days` | `28` | Number of days of history to analyze |
| `slack_webhook_url` | `''` | Slack webhook URL for posting trend report (empty = skip) |
| `post_to_discussions` | `false` | Post trend report as a GitHub Discussion (opt-in) |
| `runner` | `"ubuntu-latest"` | Runner labels as a JSON string or array |

</details>


## Configs

| Config | Purpose |
|--------|---------|
| [`.clang-tidy`](configs/.clang-tidy) | clang-analyzer, cppcoreguidelines, modernize, bugprone, performance, readability |
| [`.clang-format`](configs/.clang-format) | Standard Latest, 120-col, 4-space indent, Allman braces |
| [`.clang-tidy-naming`](configs/.clang-tidy-naming) | snake_case functions, PascalCase types, trailing `_` private |
| [`eslint-naming.config.mjs`](configs/eslint-naming.config.mjs) | TypeScript naming: snake_case, PascalCase types and .tsx components, no `I` prefix, trailing `_` private |
| [`cppcheck.suppress`](configs/cppcheck.suppress) | Generic suppressions with vendor examples |
| [`naming-exceptions.txt`](configs/naming-exceptions.txt) | File naming exceptions, one regex per line |
| [`.pre-commit-config.yaml`](configs/.pre-commit-config.yaml) | clang-format, clang-tidy, cppcheck hooks |
| [`CMakePresets-sanitizers.json`](configs/CMakePresets-sanitizers.json) | ASan, TSan, release-hardened presets |
| [`ci-multi-compiler.yml`](configs/ci-multi-compiler.yml) | GCC-13 and Clang-21 matrix, ccache |
| [`ci-fuzz.yml`](configs/ci-fuzz.yml) | libFuzzer with corpus caching |
| [`ci-codeql.yml`](configs/ci-codeql.yml) | CodeQL for C++ and Python |
| [`ci-infer.yml`](configs/ci-infer.yml) | Infer: Pulse, InferBO, RacerD |
| [`cmake-warnings.cmake`](configs/cmake-warnings.cmake) | `-Wall -Wextra -Wpedantic -Werror` plus extras |
| [`test-checklist.md`](configs/test-checklist.md) | Test edge case checklist |
| [`repo-structure-ros2.txt`](configs/repo-structure-ros2.txt) | ROS2 package structure template |
| `repo-structure-{python,cmake-cpp,typescript,godot}.txt` | Structure templates for other project types |
| [`AGENTS.md`](configs/AGENTS.md) | Agent instructions template for consuming projects |
| [`SECURITY.md`](configs/SECURITY.md) | Security policy template |
| [`dependabot.yml`](configs/dependabot.yml) | Dependabot template |
| [`gdlintrc`](configs/gdlintrc) | GDScript naming rules for gdlint |

## Scripts

Diff-aware checks run the CI logic on files changed against a base branch:

| Script | Purpose |
|--------|---------|
| `diff-clang-tidy.sh` | clang-tidy |
| `diff-cppcheck.sh` | cppcheck |
| `diff-clang-format.sh` | clang-format |
| `diff-file-naming.sh` | snake_case naming |
| `diff-iwyu.sh` | Include-What-You-Use |
| `diff-gdlint.sh` | GDScript naming (gdlint) |
| `diff-jscpd.sh` | jscpd copy-paste detection |
| `diff-ts-naming.sh` | typescript-eslint naming-convention on changed .ts/.tsx (needs `eslint-naming.config.mjs`, eslint, typescript-eslint) |
| `diff-test-mirror.sh` | added source modules have a mirrored test |

```bash
./scripts/diff-clang-tidy.sh origin/main build "cpp hpp h"
./scripts/diff-cppcheck.sh origin/main
./scripts/diff-clang-format.sh origin/main "cpp hpp h"
./scripts/diff-file-naming.sh origin/main naming-exceptions.txt
./scripts/diff-iwyu.sh origin/main build
```

Generators and utilities:

| Script | Purpose |
|--------|---------|
| `generate-workflow.sh` | Write `.github/workflows/` YAML |
| `generate-agents-md.sh` | Write a tailored `AGENTS.md` |
| `generate-baseline.sh` | Write suppression and baseline files for incremental adoption |
| `generate-badges.sh` | Print README badge markdown |
| `install-hooks.sh` | Install git pre-commit hooks |
| `check-repo-structure.sh` | Validate directory structure against a template |
| `check-dangerous-workflows.sh` | Audit workflow files for injection patterns |
| `check-hardening.sh` | Verify ELF hardening (PIE, RELRO, NX, canary) |
| `filter-excludes.sh` | Filter file lists against exclusion patterns |
| `check-layering.sh` | Run the repo's layering contract (`.importlinter`, `.dependency-cruiser.cjs`, or `.layers` for C++ and GDScript); skips if none |

```bash
./scripts/check-repo-structure.sh configs/repo-structure-ros2.txt .
./scripts/check-hardening.sh build-hardened/bin/*
```

`.layers` lists directories lowest layer first, one per line. A lower layer may not `#include` or `preload`/`load` a higher one, and cycles fail. Use it as `PavelGuzenfeld/standard/actions/layering@main`.

TypeScript naming runs as `PavelGuzenfeld/standard/actions/ts-naming@main`: typescript-eslint on changed `.ts`/`.tsx` with `eslint-naming.config.mjs`.

## License

MIT License - see [LICENSE](LICENSE). Repo layout and contributor rules are in [AGENTS.md](AGENTS.md).
