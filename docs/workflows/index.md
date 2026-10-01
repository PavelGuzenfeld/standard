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
- [Compliance and CIS](compliance.md)
- [Install test](install-test.md)
- [Scheduled health](scheduled-health.md)
- [Pre-commit](pre-commit.md)
- [Version sync](version-sync.md)

| Workflow | Checks |
|----------|--------|
| [`cpp-quality.yml`](cpp-quality.md) | clang-tidy, cppcheck, clang-format, flawfinder, ASan/UBSan, TSan, coverage, IWYU, hardening, file naming, banned patterns |
| [`infra-lint.yml`](infra-lint.md) | ShellCheck, Hadolint, cmake-lint, dangerous-workflow audit, binary-artifact scan, Gitleaks |
| [`python-quality.yml`](python-quality.md) | ruff/flake8, pytest, diff-cover |
| [`sast-python.yml`](sast-python.md) | Semgrep, pip-audit, CodeQL |
| [`fuzz.yml`](fuzz.md) | ClusterFuzzLite; skipped without `.clusterfuzzlite/Dockerfile` |
| [`sbom.yml`](sbom.md) | Syft container SBOM, source dependency scan, Grype, license check |
| [`version-check.yml`](release.md) | SemVer in package.xml, CMakeLists.txt, pyproject.toml |
| [`auto-release.yml`](release.md) | Conventional-commit version bump, git tag, GitHub Release, SLSA provenance |
| [`trend-dashboard.yml`](trend-dashboard.md) | Weekly pass-rate report, optional Slack and Discussions posting |
| [`version-sync.yml`](version-sync.md) | Sync opt-in version files (CMakeLists.txt, pyproject.toml, package.xml, package.json, `GIT_TAG` in a caller's README) to a release tag; this repo enables only pyproject.toml |
| [`cis-compliance.yml`](compliance.md) | CIS supply-chain scan of one repo |
| [`cis-org-compliance.yml`](compliance.md) | CIS supply-chain scan across an org |
| [`compliance.yml`](compliance.md) | Scan an org for standard-ci drift, optionally open update PRs |
| [`install-test.yml`](install-test.md) | Install the package and check `find_package` from a consumer |
| [`pre-commit.yml`](pre-commit.md) | Run pre-commit hooks in CI |
| [`scheduled-health.yml`](scheduled-health.md) | Open an issue when a scheduled upstream workflow fails |
| [`release.yml`](release.md) | This repo only: triggers auto-release and version-sync on push to main |

Composite actions for single steps live in `actions/`: `diff-files`, `clang-tidy`, `cppcheck`, `clang-format`, `ruff-check`, `shellcheck`, `gitleaks`, `gdlint`, `ts-naming`, `layering`. Use one as `PavelGuzenfeld/standard/actions/<name>@<sha>`. `ruff-check` and the ruff mode of `python-quality` need a diff-cover that lists the `ruff.check` driver; Python 3.8 cannot install one (diff-cover 9.2.0 has none).
