# Fuzzing

[`fuzz.yml`](https://github.com/PavelGuzenfeld/standard/blob/main/.github/workflows/fuzz.yml): ClusterFuzzLite; skipped without `.clusterfuzzlite/Dockerfile`. Pin it to a release SHA, as [Versioning](../VERSIONING.md) says.

| Input | Default | Description |
|-------|---------|-------------|
| `sanitizer` | `address` | Sanitizer: address, undefined, memory or coverage |
| `fuzz_seconds` | `600` | Total fuzzing time in seconds |
| `language` | `c++` | Project language |
| `mode` | `code-change` | `code-change` for PRs, `batch` for scheduled full runs |
| `runner` | `"ubuntu-latest"` | Runner labels as a JSON string or array |

