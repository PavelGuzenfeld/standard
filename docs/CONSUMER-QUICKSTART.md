# Consumer Quickstart

Add `standard` quality workflows to a repo with the `standard-ci` CLI. It has no dependencies and supports Python 3.8 and newer. You also need push access and, for C++ analysis, a Docker image with your build tools.

## CLI

```bash
pip install git+https://github.com/PavelGuzenfeld/standard.git

cd /path/to/your-repo
standard-ci init --preset recommended
```

For the languages it detects (from `CMakeLists.txt`, `package.xml`, `pyproject.toml`), it writes:

- `.github/workflows/cpp-quality.yml`
- `.github/workflows/python-quality.yml` and `.github/workflows/sast-python.yml`
- `.github/workflows/infra-lint.yml`
- `.standard.yml`, which the compliance bot reads

Workflow refs are pinned to the SHA of the latest tag as `@<sha> # <tag>`. Use `--pin TAG` to pick another tag. Commit and push, and PRs run the checks.

Instead of the CLI, copy the workflow file of an existing consumer repo, for example `.github/workflows/standards.yml`. [Starter workflows](https://docs.github.com/en/actions/using-workflows/creating-starter-workflows) for C++, Python and both are in [`PavelGuzenfeld/.github`](https://github.com/PavelGuzenfeld/.github).

## Presets

| Preset | Enabled beyond defaults | Use case |
|--------|-------------------------|----------|
| `minimal` | Python SAST: Semgrep, pip-audit | Fast CI, essential checks |
| `recommended` | + clang-format, file naming, flawfinder, infra-lint | Coverage and speed balanced |
| `full` | + banned patterns, doctest, SARIF, sanitizers, IWYU, more infra-lint, CodeQL | Everything |

The inputs per preset are in `src/standard_ci/presets.py`.

## Keeping up to date

With `.standard.yml` in the repo, the compliance bot detects outdated SHA pins and opens a PR to update them. It runs from your org's `.github` repo. [Compliance](COMPLIANCE.md) covers setup.

To update by hand:

```bash
standard-ci update
standard-ci update --dry-run
standard-ci check
```
