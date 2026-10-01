# C++ quality

[`cpp-quality.yml`](https://github.com/PavelGuzenfeld/standard/blob/main/.github/workflows/cpp-quality.yml): clang-tidy, cppcheck, clang-format, flawfinder, ASan/UBSan, TSan, coverage, IWYU, hardening, file naming, banned patterns. Pin it to a release SHA, as [Versioning](../VERSIONING.md) says.

## Core

| Input | Type | Default | Description |
|-------|------|---------|-------------|

## clang-tidy

| Input | Type | Default | Description |
|-------|------|---------|-------------|

## cppcheck

| Input | Type | Default | Description |
|-------|------|---------|-------------|

## clang-format

| Input | Type | Default | Description |
|-------|------|---------|-------------|

## Flawfinder

| Input | Type | Default | Description |
|-------|------|---------|-------------|

## Sanitizers (ASan/UBSan)

| Input | Type | Default | Description |
|-------|------|---------|-------------|

## ThreadSanitizer

| Input | Type | Default | Description |
|-------|------|---------|-------------|

## Coverage

| Input | Type | Default | Description |
|-------|------|---------|-------------|

## Hardening

| Input | Type | Default | Description |
|-------|------|---------|-------------|

## BinSkim

| Input | Type | Default | Description |
|-------|------|---------|-------------|

## IWYU

| Input | Type | Default | Description |
|-------|------|---------|-------------|

## Naming & Banned Patterns

| Input | Type | Default | Description |
|-------|------|---------|-------------|

## jscpd

| Input | Type | Default | Description |
|-------|------|---------|-------------|
| `docker_image` | string | required | Docker image with clang-tidy, cppcheck, and compile_commands.json |
| `compile_commands_path` | string | `'build'` | Path to directory containing compile_commands.json (inside container) |
| `source_mount` | string | `'/workspace/src'` | Where repo source is mounted inside the container |
| `clang_tidy_config` | string | `''` | Path to .clang-tidy config (empty = use repo default) |
| `cppcheck_suppress` | string | `''` | Path to cppcheck suppressions file |
| `cppcheck_includes` | string | `''` | Space-separated include directories for cppcheck |
| `cppcheck_include_file` | string | `''` | Path to file containing include dirs for cppcheck (one per line) |
| `cppcheck_std` | string | `'c++23'` | C++ standard for cppcheck |
| `runner` | string | `'"ubuntu-latest"'` | Runner labels as JSON (e.g., "\"ubuntu-latest\"" or "[\"self-hosted\",\"X64\",\"Linux\"]") |
| `file_extensions` | string | `'cpp hpp h cc cxx'` | Space-separated C++ file extensions to check |
| `enforce_doctest` | boolean | `false` | Require doctest instead of gtest in test files |
| `test_file_pattern` | string | `'test'` | Grep pattern to identify test files (matched against path) |
| `enable_clang_format` | boolean | `false` | Enable clang-format check on changed files (opt-in) |
| `clang_format_config` | string | `''` | Path to .clang-format config (empty = use repo default) |
| `source_setup` | string | `''` | Shell command to source before running tools (e.g., source /opt/ros/humble/install/setup.bash) |
| `enable_file_naming` | boolean | `false` | Enable file/directory naming convention check (snake_case enforcement, opt-in) |
| `file_naming_exceptions` | string | `''` | Path to file with additional naming exception regexes (one per line) |
| `file_naming_allowed_prefixes` | string | `'_'` | Space-separated allowed prefixes for file/dir names (e.g., _ for pybind11 _bindings.so) |
| `ban_cout` | boolean | `false` | Ban std::cout/cerr/clog and printf family in non-test source files (opt-in) |
| `ban_new` | boolean | `false` | Ban raw new/delete in non-test source files (opt-in) |
| `clang_tidy_jobs` | number | `4` | Parallel clang-tidy jobs inside Docker container |
| `exclude_file` | string | `''` | Path to file listing excluded paths (one per line, # comments) |
| `enable_flawfinder` | boolean | `false` | Enable flawfinder CWE lexical scan (opt-in) |
| `flawfinder_min_level` | number | `2` | Minimum flawfinder finding level (1-5) |
| `enable_sarif` | boolean | `false` | Upload SARIF to GitHub Security tab (requires security-events: write) |
| `pre_analysis_script` | string | `''` | Script path (in repo) to run inside Docker before analysis (build compile_commands.json, etc.) |
| `build_cache_key` | string | `''` | Cache key for build artifacts (empty = no caching) |
| `build_cache_paths` | string | `'build install'` | Space-separated paths to cache |
| `checkout_submodules` | string | `'false'` | Pass to actions/checkout submodules parameter (false, true, recursive) |
| `enable_sanitizers` | boolean | `false` | Enable ASAN/UBSAN test job |
| `sanitizer_script` | string | `''` | Script to build+test with sanitizers (in repo). If empty, uses default colcon flow. |
| `sanitizer_suppressions` | string | `''` | Path to LSAN suppressions file (in repo) |
| `sanitizer_packages` | string | `''` | Space-separated packages to test (empty = all) |
| `enable_iwyu` | boolean | `false` | Enable Include-What-You-Use analysis (opt-in, non-blocking) |
| `iwyu_script` | string | `''` | Script to run IWYU analysis (in repo). If empty, uses default flow. |
| `iwyu_mapping_file` | string | `''` | Path to IWYU mapping file (.imp) in repo |
| `enable_tsan` | boolean | `false` | Enable ThreadSanitizer (TSAN) test job (mutually exclusive with ASAN) |
| `tsan_script` | string | `''` | Script to build+test with TSAN (in repo). If empty, uses default colcon flow. |
| `tsan_suppressions` | string | `''` | Path to TSAN suppressions file (in repo) |
| `tsan_packages` | string | `''` | Space-separated packages to test with TSAN (empty = all) |
| `enable_coverage` | boolean | `false` | Enable gcov/lcov test coverage reporting (opt-in, non-blocking) |
| `coverage_script` | string | `''` | Script to build+test with coverage and collect lcov (in repo). If empty, uses default flow. |
| `coverage_packages` | string | `''` | Space-separated packages to measure coverage (empty = all) |
| `coverage_threshold` | string | `'0'` | Minimum overall line coverage % (0 = no threshold, job always passes) |
| `coverage_diff_threshold` | string | `'0'` | Minimum line coverage % for changed lines via diff-cover (0 = disabled) |
| `coverage_diff_report` | boolean | `false` | Generate diff-cover markdown report as artifact |
| `enable_hardening` | boolean | `false` | Enable binary hardening verification (PIE, RELRO, stack canary, NX, CET) |
| `hardening_script` | string | `''` | Script to build with hardening flags (in repo). If empty, uses cmake --preset release-hardened. |
| `hardening_binary_paths` | string | `'build-hardened/bin/*'` | Space-separated globs to ELF binaries to check (inside container) |
| `hardening_skip_checks` | string | `''` | Space-separated checks to skip: pie relro bindnow canary fortify nx cet |
| `select_jobs` | string | `'all'` | Comma-separated jobs to run (all, clang-tidy, cppcheck, coverage, tsan, sanitizers, iwyu, clang-format, doctest, file-naming, cout-ban, new-delete-ban, flawfinder, hardening, binskim, jscpd) |
| `base_ref` | string | `''` | Base branch for diff (fallback when github.base_ref is empty, e.g. workflow_dispatch) |
| `enable_clang_tidy` | boolean | `true` | Enable clang-tidy analysis (on by default for backward compat) |
| `enable_cppcheck` | boolean | `true` | Enable cppcheck analysis (on by default for backward compat) |
| `cppcheck_inconclusive` | boolean | `false` | Enable cppcheck --inconclusive mode (may produce false positives) |
| `cppcheck_strict` | boolean | `false` | Use --error-exitcode=1 for native cppcheck error handling |
| `enable_jscpd` | boolean | `false` | Enable jscpd copy-paste detection on changed files (opt-in) |
| `jscpd_threshold` | number | `5` | Maximum duplicated lines in percent before jscpd flags the changed files |
| `jscpd_report_only` | boolean | `true` | Report jscpd duplication as a warning without failing the job |
| `enable_binskim` | boolean | `false` | Enable BinSkim ELF analysis (stack clash, SafeStack, checked functions; opt-in) |
| `binskim_paths` | string | `'build-hardened/bin'` | Space-separated files or directories of built ELF binaries for BinSkim |
| `binskim_fail_level` | string | `'error'` | Lowest BinSkim result level that fails the job: error, warning or note |

