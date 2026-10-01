# Python SAST

[`sast-python.yml`](https://github.com/PavelGuzenfeld/standard/blob/main/.github/workflows/sast-python.yml): Semgrep, pip-audit, CodeQL. Pin it to a release SHA, as [Versioning](../VERSIONING.md) says.

| Input | Type | Default | Description |
|-------|------|---------|-------------|
| `python_version` | string | `'3.12'` | Python version to use |
| `enable_semgrep` | boolean | `true` | Enable Semgrep security scanning |
| `semgrep_version` | string | `'1.150.0'` | Semgrep Docker image version (pin to avoid breaking changes) |
| `semgrep_rules` | string | `'p/python p/owasp-top-ten'` | Semgrep rule sets (space-separated) |
| `enable_pip_audit` | boolean | `true` | Enable pip-audit dependency CVE scanning |
| `requirements_file` | string | `'requirements.txt'` | Path to requirements file for pip-audit |
| `enable_codeql` | boolean | `false` | Enable CodeQL deep analysis (free for public repos) |
| `codeql_queries` | string | `'security-extended'` | CodeQL query suite: security-extended (recommended) or security-and-quality |
| `enable_code_scanning` | boolean | `true` | Upload SARIF to code scanning. A private repo without Advanced Security rejects the upload — set `false` there and read the artifact |
| `runner` | string | `'"ubuntu-latest"'` | Runner labels as JSON (e.g., "\"ubuntu-latest\"" or "[\"self-hosted\",\"X64\",\"Linux\"]") |

