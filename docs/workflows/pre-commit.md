# Pre-commit

[`pre-commit.yml`](https://github.com/PavelGuzenfeld/standard/blob/main/.github/workflows/pre-commit.yml): Run pre-commit hooks in CI. Pin to a release SHA, as [Versioning](../VERSIONING.md) says.

| Input | Type | Default | Description |
|-------|------|---------|-------------|
| `python_version` | string | `'3.13'` | Python version for pre-commit |
| `config_file` | string | `'.pre-commit-config.yaml'` | Path to pre-commit config file |
| `runner` | string | `'"ubuntu-latest"'` | Runner labels as JSON |
