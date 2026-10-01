# Python quality

[`python-quality.yml`](https://github.com/PavelGuzenfeld/standard/blob/main/.github/workflows/python-quality.yml): ruff/flake8, pytest, diff-cover. Pin it to a release SHA, as [Versioning](../VERSIONING.md) says.

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

