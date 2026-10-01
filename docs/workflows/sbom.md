# SBOM

[`sbom.yml`](https://github.com/PavelGuzenfeld/standard/blob/main/.github/workflows/sbom.yml): Syft container SBOM, source dependency scan, Grype, license check. Pin it to a release SHA, as [Versioning](../VERSIONING.md) says.

| Input | Default | Description |
|-------|---------|-------------|
| `docker_image` | *required* | Docker image to scan |
| `source_sbom_script` | `''` | Path to source-level SBOM generation script (empty = skip) |
| `grype_fail_on` | `''` | Fail on severity: "" = report-only, "critical", "high", "medium", "low" |
| `grype_ignore_file` | `''` | Path to .grype.yaml ignore file |
| `checkout_submodules` | `false` | Checkout submodules for source SBOM (true/false/recursive) |
| `license_policy_file` | `''` | Path to license policy YAML (empty = skip license check) |
| `license_check_script` | `''` | Path to license check Python script in caller repo |
| `enable_code_scanning` | `true` | Upload SARIF to code scanning (set `false` on a private repo without Advanced Security) |
| `runner` | `"ubuntu-latest"` | Runner labels as a JSON string or array |

