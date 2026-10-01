# Python SAST

[`sast-python.yml`](https://github.com/PavelGuzenfeld/standard/blob/main/.github/workflows/sast-python.yml): Semgrep, pip-audit, CodeQL. Pin it to a release SHA, as [Versioning](../VERSIONING.md) says.

| Input | Default | Description |
|-------|---------|-------------|
| `python_version` | `3.12` | Python version to use |
| `enable_semgrep` | `true` | Enable Semgrep security scanning |
| `semgrep_version` | `1.150.0` | Semgrep Docker image version (pin to avoid breaking changes) |
| `semgrep_rules` | `p/python p/owasp-top-ten` | Semgrep rule sets |
| `enable_pip_audit` | `true` | Enable pip-audit CVE scanning |
| `requirements_file` | `requirements.txt` | Path to requirements file |
| `enable_codeql` | `false` | Enable CodeQL (free for public repos) |
| `codeql_queries` | `security-extended` | CodeQL query suite |
| `enable_code_scanning` | `true` | Upload SARIF to code scanning (set `false` on a private repo without Advanced Security) |
| `runner` | `"ubuntu-latest"` | Runner labels as a JSON string or array |

