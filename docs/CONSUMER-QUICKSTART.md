# Quickstart

Add the quality workflows to a repo with the `standard-ci` CLI. It has no dependencies and supports Python 3.8 and newer. You need push access and, for C++ analysis, a Docker image with your build tools.

## 1. Install and generate

```bash
pip install git+https://github.com/PavelGuzenfeld/standard.git
cd your-repo
standard-ci init --preset recommended
```

It detects languages from `CMakeLists.txt`, `package.xml` and `pyproject.toml`, and writes:

- `.github/workflows/cpp-quality.yml`
- `.github/workflows/python-quality.yml` and `.github/workflows/sast-python.yml`
- `.github/workflows/infra-lint.yml`
- `.standard.yml`, which the compliance bot reads

Each ref is pinned to the SHA of the latest tag, with the tag as a comment. Use `--pin TAG` to pick another tag:

```yaml
uses: PavelGuzenfeld/standard/.github/workflows/cpp-quality.yml@d5c13383c0f780fa19dea17d3157076fe9e8efd9 # v0.23.17
```

## 2. Pick a preset

| Preset | Enabled beyond defaults | Use case |
|--------|-------------------------|----------|
| `minimal` | Python SAST: Semgrep, pip-audit | Fast CI, essential checks |
| `recommended` | + clang-format, file naming, flawfinder, infra-lint | Coverage and speed balanced |
| `full` | + banned patterns, doctest, SARIF, sanitizers, IWYU, more infra-lint, CodeQL | Everything |

The inputs per preset are in `src/standard_ci/presets.py`.

## 3. Commit and push

The next PR runs the checks. To copy a workflow by hand instead, use the [starter workflows](https://github.com/PavelGuzenfeld/.github).

## 4. Keep the pins current

```bash
standard-ci update
standard-ci update --dry-run
standard-ci check
```

With `.standard.yml` in the repo, the compliance bot also opens a PR for outdated pins. [Compliance](COMPLIANCE.md) covers setup.
