# Fuzzing

[`fuzz.yml`](https://github.com/PavelGuzenfeld/standard/blob/main/.github/workflows/fuzz.yml): ClusterFuzzLite; skipped without `.clusterfuzzlite/Dockerfile`. Pin it to a release SHA, as [Versioning](../VERSIONING.md) says.

| Input | Type | Default | Description |
|-------|------|---------|-------------|
| `sanitizer` | string | `'address'` | Sanitizer: address, undefined, memory or coverage |
| `fuzz_seconds` | number | `600` | Total fuzzing time in seconds |
| `language` | string | `'c++'` | Project language: c, c++, go, rust, python, jvm or swift |
| `mode` | string | `'code-change'` | `code-change` for PRs, `batch` for scheduled full runs |
| `runner` | string | `'"ubuntu-latest"'` | Runner labels as JSON (e.g., "\"ubuntu-latest\"" or "[\"self-hosted\",\"X64\",\"Linux\"]") |

