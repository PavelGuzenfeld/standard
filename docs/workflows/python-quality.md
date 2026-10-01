# Python quality

[`python-quality.yml`](https://github.com/PavelGuzenfeld/standard/blob/main/.github/workflows/python-quality.yml): ruff/flake8, pytest, diff-cover. Pin it to a release SHA, as [Versioning](../VERSIONING.md) says.

| Input | Type | Default | Description |
|-------|------|---------|-------------|
| `python_version` | string | `'3.12'` | Python version to use |
| `target_python` | string | `'py38'` | Target Python version for ruff (e.g., py38) |
| `python_linter` | string | `'ruff'` | Linter backend: ruff (default, fast) or flake8 (ROS2/ament compat) |
| `source_dirs` | string | `'src'` | Space-separated source directories |
| `test_dirs` | string | `'tests'` | Space-separated test directories |
| `ruff_version` | string | `'0.16.9'` | Ruff version (pin to avoid breaking changes) |
| `diff_cover_version` | string | `''` | diff-cover version (empty picks 10.5.1, or 9.2.0 on Python below 3.10, which has no ruff.check driver) |
| `ruff_select` | string | `'E,W,F,I,N'` | Ruff rule selection (comma-separated). Overrides select in pyproject.toml |
| `ruff_ignore` | string | `'E501'` | Ruff rules to ignore (comma-separated). Overrides ignore in pyproject.toml; empty ignores nothing |
| `enable_tests` | boolean | `true` | Run pytest and collect coverage (disable for projects with external test deps like ROS2) |
| `base_ref` | string | `''` | Base branch for diff comparison (falls back to github.base_ref, then main) |
| `fail_under` | string | `'100'` | Minimum diff-quality score (0-100) |
| `runner` | string | `'"ubuntu-latest"'` | Runner labels as JSON (e.g., "\"ubuntu-latest\"" or "[\"self-hosted\",\"X64\",\"Linux\"]") |

