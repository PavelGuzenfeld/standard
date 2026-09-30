# Consumer Quick-Start Guide

How to integrate `standard` quality workflows into your repo.

## Prerequisites

- Your repo has C++ and/or Python source code
- You have a Docker image with your build tools (for C++ analysis)
- You have push access to the repo

## Option 1: CLI (Recommended)

```bash
pip install git+https://github.com/PavelGuzenfeld/standard.git

cd /path/to/your-repo
standard-ci init --preset recommended
```

This generates, for the languages it detects:
- `.github/workflows/cpp-quality.yml`
- `.github/workflows/python-quality.yml` and `.github/workflows/sast-python.yml`
- `.github/workflows/infra-lint.yml`
- `.standard.yml` — config file for the compliance bot

Commit and push. PRs will now run quality checks.

## Option 2: Copy from an existing repo

Look at an existing consumer repo's `.github/workflows/standards.yml` for a working example
with all features enabled.

## Presets

| Preset | Enabled beyond defaults | Use case |
|--------|-------------------------|----------|
| `minimal` | Python SAST: Semgrep, pip-audit | Fast CI, essential checks only |
| `recommended` | + clang-format, file naming, flawfinder, infra-lint | Good balance of coverage and speed |
| `full` | + banned patterns, doctest, SARIF, sanitizers, IWYU, more infra-lint, CodeQL | Maximum quality enforcement |

The exact inputs per preset are in `src/standard_ci/presets.py`.

## Keeping up to date

Once `.standard.yml` exists in your repo, the compliance bot will:
- Detect when your SHA pins are outdated
- Automatically open a PR to update them
- You just review and merge

The bot runs from your org's `.github` repo (e.g. `my-org/.github`).
See [COMPLIANCE.md](COMPLIANCE.md) for setup instructions if your org
doesn't have trigger workflows yet.

To update manually:

```bash
standard-ci update          # update to latest
standard-ci update --dry-run # preview changes
standard-ci check           # verify current setup
```
