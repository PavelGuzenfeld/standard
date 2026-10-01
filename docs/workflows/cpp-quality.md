# C++ quality

[`cpp-quality.yml`](https://github.com/PavelGuzenfeld/standard/blob/main/.github/workflows/cpp-quality.yml): clang-tidy, cppcheck, clang-format, flawfinder, ASan/UBSan, TSan, coverage, IWYU, hardening, file naming, banned patterns. Pin it to a release SHA, as [Versioning](../VERSIONING.md) says.

## Core

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
| `select_jobs` | `all` | Comma-separated jobs to run (all, clang-tidy, cppcheck, coverage, tsan, sanitizers, iwyu, clang-format, doctest, file-naming, cout-ban, new-delete-ban, flawfinder, hardening, binskim, jscpd) |
| `base_ref` | `''` | Base branch for diff (fallback when github.base_ref is empty) |

## clang-tidy

| Input | Default | Description |
|-------|---------|-------------|
| `enable_clang_tidy` | `true` | Enable clang-tidy analysis |
| `clang_tidy_config` | `''` | Path to .clang-tidy config (empty = use repo default) |
| `clang_tidy_jobs` | `4` | Parallel clang-tidy jobs inside Docker |

## cppcheck

| Input | Default | Description |
|-------|---------|-------------|
| `enable_cppcheck` | `true` | Enable cppcheck analysis |
| `cppcheck_suppress` | `''` | Path to cppcheck suppressions file |
| `cppcheck_includes` | `''` | Space-separated include directories |
| `cppcheck_include_file` | `''` | Path to file containing include dirs (one per line) |
| `cppcheck_std` | `c++23` | C++ standard for cppcheck |
| `cppcheck_inconclusive` | `false` | Enable --inconclusive mode (may produce false positives) |
| `cppcheck_strict` | `false` | Use --error-exitcode=1 for native cppcheck error handling |

## clang-format

| Input | Default | Description |
|-------|---------|-------------|
| `enable_clang_format` | `false` | Enable clang-format check (opt-in) |
| `clang_format_config` | `''` | Path to .clang-format config |

## Flawfinder

| Input | Default | Description |
|-------|---------|-------------|
| `enable_flawfinder` | `false` | Enable flawfinder CWE lexical scan (opt-in) |
| `flawfinder_min_level` | `2` | Minimum flawfinder finding level (1-5) |
| `enable_sarif` | `false` | Upload SARIF to GitHub Security tab |

## Sanitizers (ASan/UBSan)

| Input | Default | Description |
|-------|---------|-------------|
| `enable_sanitizers` | `false` | Enable ASan/UBSan test job (opt-in) |
| `sanitizer_script` | `''` | Script to build+test with sanitizers |
| `sanitizer_suppressions` | `''` | Path to LSAN suppressions file |
| `sanitizer_packages` | `''` | Space-separated packages to test (empty = all) |

## ThreadSanitizer

| Input | Default | Description |
|-------|---------|-------------|
| `enable_tsan` | `false` | Enable TSan test job (opt-in, mutually exclusive with ASan) |
| `tsan_script` | `''` | Script to build+test with TSan |
| `tsan_suppressions` | `''` | Path to TSan suppressions file |
| `tsan_packages` | `''` | Space-separated packages to test with TSan (empty = all) |

## Coverage

| Input | Default | Description |
|-------|---------|-------------|
| `enable_coverage` | `false` | Enable gcov/lcov coverage reporting (opt-in) |
| `coverage_script` | `''` | Script to build+test with coverage and collect lcov |
| `coverage_packages` | `''` | Space-separated packages to measure (empty = all) |
| `coverage_threshold` | `0` | Minimum overall line coverage % (0 = no threshold) |
| `coverage_diff_threshold` | `0` | Minimum coverage % for changed lines via diff-cover (0 = disabled) |
| `coverage_diff_report` | `false` | Generate diff-cover markdown report as artifact |

## Hardening

| Input | Default | Description |
|-------|---------|-------------|
| `enable_hardening` | `false` | Enable binary hardening verification (opt-in) |
| `hardening_script` | `''` | Script to build with hardening flags |
| `hardening_binary_paths` | `build-hardened/bin/*` | Space-separated globs to ELF binaries to check |
| `hardening_skip_checks` | `''` | Space-separated checks to skip: pie relro bindnow canary fortify nx cet |

## BinSkim

| Input | Default | Description |
|-------|---------|-------------|
| `enable_binskim` | `false` | Enable BinSkim ELF analysis (opt-in); builds like `enable_hardening` (`hardening_script` or `release-hardened` preset) |
| `binskim_paths` | `build-hardened/bin` | Space-separated files or directories of built ELF binaries |
| `binskim_fail_level` | `error` | Lowest result level that fails the job: error, warning or note. SARIF is uploaded as `binskim-sarif` |

## IWYU

| Input | Default | Description |
|-------|---------|-------------|
| `enable_iwyu` | `false` | Enable Include-What-You-Use analysis (opt-in) |
| `iwyu_script` | `''` | Script to run IWYU analysis |
| `iwyu_mapping_file` | `''` | Path to IWYU mapping file (.imp) |

## Naming & Banned Patterns

| Input | Default | Description |
|-------|---------|-------------|
| `enable_file_naming` | `false` | Enable snake_case file naming check (opt-in) |
| `file_naming_exceptions` | `''` | Path to naming exception regexes |
| `file_naming_allowed_prefixes` | `_` | Allowed prefixes for file names |
| `enforce_doctest` | `false` | Require doctest instead of gtest (opt-in) |
| `test_file_pattern` | `test` | Grep pattern to identify test files |
| `ban_cout` | `false` | Ban cout/cerr/printf in non-test files (opt-in) |
| `ban_new` | `false` | Ban raw new/delete in non-test files (opt-in) |

## jscpd

| Input | Default | Description |
|-------|---------|-------------|
| `enable_jscpd` | `false` | Enable jscpd copy-paste detection on changed files (opt-in) |
| `jscpd_threshold` | `5` | Maximum duplicated lines in percent before jscpd flags the changed files |
| `jscpd_report_only` | `true` | Report duplication as a warning without failing the job |

