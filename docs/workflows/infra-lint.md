# Infra lint

[`infra-lint.yml`](https://github.com/PavelGuzenfeld/standard/blob/main/.github/workflows/infra-lint.yml): ShellCheck, Hadolint, cmake-lint, dangerous-workflow audit, binary-artifact scan, Gitleaks. Pin it to a release SHA, as [Versioning](../VERSIONING.md) says.

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

