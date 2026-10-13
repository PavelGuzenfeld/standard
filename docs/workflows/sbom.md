# SBOM

[`sbom.yml`](https://github.com/PavelGuzenfeld/standard/blob/main/.github/workflows/sbom.yml): Syft container SBOM, source dependency scan, Grype, license check. Pin it to a release SHA, as [Versioning](../VERSIONING.md) says.

The container SBOM and license report are cached by image digest, policy and workflow sha, and that cache is shared across PRs only when sbom.yml also runs on pushes to the default branch, because GitHub scopes a PR's cache to that PR.

| Input | Type | Default | Description |
|-------|------|---------|-------------|
| `docker_image` | string | required | Docker image to scan (e.g., ghcr.io/org/image:tag) |
| `source_sbom_script` | string | `''` | Path to source-level SBOM generation script (empty = skip) |
| `grype_fail_on` | string | `''` | Fail on severity: "" = report-only, "critical", "high", "medium", "low" |
| `grype_ignore_file` | string | `''` | Path to .grype.yaml ignore file |
| `enable_code_scanning` | boolean | `true` | Upload SARIF to code scanning. A private repo without Advanced Security rejects the upload — set `false` there and read the artifact |
| `runner` | string | `'"ubuntu-latest"'` | Runner labels as JSON (e.g., "\"ubuntu-latest\"" or "[\"self-hosted\",\"X64\",\"Linux\"]") |
| `checkout_submodules` | string | `'false'` | Checkout submodules for source SBOM (true/false/recursive) |
| `license_policy_file` | string | `''` | Path to license policy YAML (empty = skip license check) |
| `license_check_script` | string | `''` | Path to license check Python script in caller repo |

