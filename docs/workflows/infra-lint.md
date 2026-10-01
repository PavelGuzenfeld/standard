# Infra lint

[`infra-lint.yml`](https://github.com/PavelGuzenfeld/standard/blob/main/.github/workflows/infra-lint.yml): ShellCheck, Hadolint, cmake-lint, dangerous-workflow audit, binary-artifact scan, Gitleaks. Pin it to a release SHA, as [Versioning](../VERSIONING.md) says.

| Input | Type | Default | Description |
|-------|------|---------|-------------|
| `enable_shellcheck` | boolean | `false` | Enable ShellCheck for shell scripts (opt-in) |
| `shellcheck_severity` | string | `'warning'` | ShellCheck minimum severity: error, warning, info, style |
| `enable_hadolint` | boolean | `false` | Enable Hadolint for Dockerfiles (opt-in) |
| `hadolint_config` | string | `''` | Path to .hadolint.yaml config file (empty = defaults) |
| `enable_cmake_lint` | boolean | `false` | Enable cmake-lint for CMake files (opt-in) |
| `cmake_lint_config` | string | `''` | Path to .cmake-format.yaml config file (empty = defaults) |
| `exclude_file` | string | `''` | Path to file listing excluded paths (one per line, # comments) |
| `base_ref` | string | `''` | Base branch for diff (fallback when github.base_ref is empty) |
| `runner` | string | `'"ubuntu-latest"'` | Runner labels as JSON (e.g., "\"ubuntu-latest\"" or "[\"self-hosted\",\"X64\",\"Linux\"]") |
| `enable_dangerous_workflows` | boolean | `false` | Enable dangerous-workflow pattern audit (opt-in) |
| `enable_binary_artifacts` | boolean | `false` | Enable binary artifact detection in PRs (opt-in) |
| `enable_gitleaks` | boolean | `false` | Enable Gitleaks secrets detection (opt-in) |
| `gitleaks_config` | string | `''` | Path to .gitleaks.toml config file (empty = defaults) |
| `select_jobs` | string | `'all'` | Comma-separated jobs to run (all, shellcheck, hadolint, cmake-lint, dangerous-workflows, binary-artifacts, gitleaks) |
