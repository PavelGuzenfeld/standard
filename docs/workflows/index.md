# Workflows

Pin a workflow to a release SHA, not `@main`, in production. [Versioning](../VERSIONING.md) covers tags.

Inputs and defaults are on one page per family:

- [C++ quality](cpp-quality.md)
- [Infra lint](infra-lint.md)
- [Python quality](python-quality.md)
- [Python SAST](sast-python.md)
- [SBOM](sbom.md)
- [Fuzzing](fuzz.md)
- [Trend dashboard](trend-dashboard.md)
- [Version check and release](release.md)

| Workflow | Checks |
|----------|--------|
| [`cpp-quality.yml`](https://github.com/PavelGuzenfeld/standard/blob/main/.github/workflows/cpp-quality.yml) | clang-tidy, cppcheck, clang-format, flawfinder, ASan/UBSan, TSan, coverage, IWYU, hardening, file naming, banned patterns |
| [`infra-lint.yml`](https://github.com/PavelGuzenfeld/standard/blob/main/.github/workflows/infra-lint.yml) | ShellCheck, Hadolint, cmake-lint, dangerous-workflow audit, binary-artifact scan, Gitleaks |
| [`python-quality.yml`](https://github.com/PavelGuzenfeld/standard/blob/main/.github/workflows/python-quality.yml) | ruff/flake8, pytest, diff-cover |
| [`sast-python.yml`](https://github.com/PavelGuzenfeld/standard/blob/main/.github/workflows/sast-python.yml) | Semgrep, pip-audit, CodeQL |
| [`fuzz.yml`](https://github.com/PavelGuzenfeld/standard/blob/main/.github/workflows/fuzz.yml) | ClusterFuzzLite; skipped without `.clusterfuzzlite/Dockerfile` |
| [`sbom.yml`](https://github.com/PavelGuzenfeld/standard/blob/main/.github/workflows/sbom.yml) | Syft container SBOM, source dependency scan, Grype, license check |
| [`version-check.yml`](https://github.com/PavelGuzenfeld/standard/blob/main/.github/workflows/version-check.yml) | SemVer in package.xml, CMakeLists.txt, pyproject.toml |
| [`auto-release.yml`](https://github.com/PavelGuzenfeld/standard/blob/main/.github/workflows/auto-release.yml) | Conventional-commit version bump, git tag, GitHub Release, SLSA provenance |
| [`trend-dashboard.yml`](https://github.com/PavelGuzenfeld/standard/blob/main/.github/workflows/trend-dashboard.yml) | Weekly pass-rate report, optional Slack and Discussions posting |
| [`version-sync.yml`](https://github.com/PavelGuzenfeld/standard/blob/main/.github/workflows/version-sync.yml) | Sync opt-in version files (CMakeLists.txt, pyproject.toml, package.xml, package.json, `GIT_TAG` in a caller's README) to a release tag; this repo enables only pyproject.toml |
| [`cis-compliance.yml`](https://github.com/PavelGuzenfeld/standard/blob/main/.github/workflows/cis-compliance.yml) | CIS supply-chain scan of one repo |
| [`cis-org-compliance.yml`](https://github.com/PavelGuzenfeld/standard/blob/main/.github/workflows/cis-org-compliance.yml) | CIS supply-chain scan across an org |
| [`compliance.yml`](https://github.com/PavelGuzenfeld/standard/blob/main/.github/workflows/compliance.yml) | Scan an org for standard-ci drift, optionally open update PRs |
| [`install-test.yml`](https://github.com/PavelGuzenfeld/standard/blob/main/.github/workflows/install-test.yml) | Install the package and check `find_package` from a consumer |
| [`pre-commit.yml`](https://github.com/PavelGuzenfeld/standard/blob/main/.github/workflows/pre-commit.yml) | Run pre-commit hooks in CI |
| [`scheduled-health.yml`](https://github.com/PavelGuzenfeld/standard/blob/main/.github/workflows/scheduled-health.yml) | Open an issue when a scheduled upstream workflow fails |
| [`release.yml`](https://github.com/PavelGuzenfeld/standard/blob/main/.github/workflows/release.yml) | This repo only: triggers auto-release and version-sync on push to main |

Composite actions for single steps live in `actions/`: `diff-files`, `clang-tidy`, `cppcheck`, `clang-format`, `ruff-check`, `shellcheck`, `gitleaks`, `gdlint`, `ts-naming`, `layering`. Use one as `PavelGuzenfeld/standard/actions/<name>@<sha>`. `ruff-check` and the ruff mode of `python-quality` need a diff-cover that lists the `ruff.check` driver; Python 3.8 cannot install one (diff-cover 9.2.0 has none).
