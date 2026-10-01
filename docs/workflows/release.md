# Version check and release

[`version-check.yml`](https://github.com/PavelGuzenfeld/standard/blob/main/.github/workflows/version-check.yml): SemVer in package.xml, CMakeLists.txt, pyproject.toml. [`auto-release.yml`](https://github.com/PavelGuzenfeld/standard/blob/main/.github/workflows/auto-release.yml): Conventional-commit version bump, git tag, GitHub Release, SLSA provenance. Pin both to a release SHA, as [Versioning](../VERSIONING.md) says.

## Version Check

| Input | Type | Default | Description |
|-------|------|---------|-------------|
| `exclude_file` | string | `''` | Path to file listing excluded paths (one per line, # comments) |
| `base_ref` | string | `''` | Base branch for diff (fallback when github.base_ref is empty) |
| `runner` | string | `'"ubuntu-latest"'` | Runner labels as JSON (e.g., "\"ubuntu-latest\"" or "[\"self-hosted\",\"X64\",\"Linux\"]") |

## Auto-Release

| Input | Type | Default | Description |
|-------|------|---------|-------------|
| `default_bump` | string | `'patch'` | Default bump when no conventional commit prefix detected |
| `enable_provenance` | boolean | `false` | Enable SLSA provenance attestation for releases (opt-in) |

