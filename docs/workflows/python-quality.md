# Python quality

[`python-quality.yml`](https://github.com/PavelGuzenfeld/standard/blob/main/.github/workflows/python-quality.yml): ruff/flake8, pytest, diff-cover. Pin it to a release SHA, as [Versioning](../VERSIONING.md) says.

| Input | Default | Description |
|-------|---------|-------------|
| `python_version` | `3.12` | Python version to use |
| `target_python` | `py38` | Target Python version for ruff |
| `python_linter` | `ruff` | Linter: `ruff` or `flake8` |
| `source_dirs` | `src` | Source directories |
| `test_dirs` | `tests` | Test directories |
| `ruff_version` | `0.16.9` | Ruff version to install; matches the `ruff-pre-commit` pin |
| `diff_cover_version` | empty | diff-cover version to install, for either linter. Empty picks `10.5.1`, or `9.2.0` on Python below 3.10. 9.2.0 has no `ruff.check` driver, so the ruff lint step fails with that reason there; use `python_linter: flake8` or a newer `python_version` |
| `ruff_select` | `E,W,F,I,N` | Ruff rule selection. Overrides `select` in pyproject.toml |
| `ruff_ignore` | `E501` | Ruff rules to ignore. Overrides `ignore` in pyproject.toml, so CI agrees with pre-commit; empty ignores nothing |
| `enable_tests` | `true` | Run pytest and collect coverage (disable for projects with external test deps like ROS2) |
| `base_ref` | `''` | Base branch for diff comparison (falls back to github.base_ref, then main) |
| `fail_under` | `100` | Minimum diff-quality score (0-100) |
| `runner` | `"ubuntu-latest"` | Runner labels as a JSON string or array |

