# Version check and release

[`version-check.yml`](https://github.com/PavelGuzenfeld/standard/blob/main/.github/workflows/version-check.yml): SemVer in package.xml, CMakeLists.txt, pyproject.toml. [`auto-release.yml`](https://github.com/PavelGuzenfeld/standard/blob/main/.github/workflows/auto-release.yml): Conventional-commit version bump, git tag, GitHub Release, SLSA provenance. Pin both to a release SHA, as [Versioning](../VERSIONING.md) says.

## Version Check

| Input | Default | Description |
|-------|---------|-------------|
| `exclude_file` | `''` | Path to file listing excluded paths (one per line, `#` comments) |
| `base_ref` | `''` | Base branch for diff (fallback when github.base_ref is empty) |
| `runner` | `"ubuntu-latest"` | Runner labels as a JSON string or array |

## Auto-Release

| Input | Default | Description |
|-------|---------|-------------|
| `default_bump` | `patch` | Default bump when no conventional commit prefix detected |
| `enable_provenance` | `false` | Enable SLSA provenance attestation for releases (opt-in) |

