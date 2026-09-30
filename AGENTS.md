# Agent Instructions

Instructions for AI agents contributing to this repository.

## Overview

This repo provides reusable GitHub Actions workflows for diff-aware C++ and Python quality gates. Only changed files are checked — legacy code never blocks PRs.

## Project Structure

```
.github/workflows/   Reusable workflows (workflow_call) and this repo's own CI
actions/             Composite actions
scripts/             Diff-aware checks, generators, and utilities
configs/             Drop-in configs, CI templates, and agent instructions
src/standard_ci/     standard-ci CLI package
src/calculator.py    Python demo module
tests/               Bash pattern and script tests, pytest suites
docs/                SDLC, integration, versioning, roadmap, comparison, compliance, quickstart
AGENTS.md            AI agent instructions for contributing to this repo
```

## Running Tests

```bash
bash tests/test_patterns.sh
bash tests/test_layering.sh
bash tests/test_repo_structure.sh
bash tests/test_test_mirror.sh
pytest tests
```

`test_patterns.sh` validates grep/regex patterns used by the workflow jobs and scripts. Every assertion must pass.

## Adding a New Check

Follow this pattern (every existing check follows it):

1. **Workflow job** — Add a job in `cpp-quality.yml` or `python-quality.yml` with an `enable_*` or `ban_*` input (default `false` for opt-in checks)
2. **Script** (if needed) — Add `scripts/diff-<name>.sh` for the diff-aware logic
3. **Config** (if needed) — Add a template config in `configs/`
4. **Tests** — Add a numbered section in `tests/test_patterns.sh`
5. **Docs** — Update README.md (Workflow Inputs table, Configs table), INTEGRATION.md (setup steps), and SDLC.md (lifecycle phases)

### Workflow Job Conventions

- Jobs that are always-on: `clang-tidy`, `cppcheck`, diff-aware linting
- Opt-in jobs: gated by a boolean input defaulting to `false`
- Jobs post annotations via `::warning file=...`
- The `summary` job collects all results and posts/updates a single PR comment

### Script Conventions

Two script families:

**`diff-*` scripts** — diff-aware analysis:
- Take `base_ref` as the first argument (e.g., `origin/main`)
- Changed files detected with: `git diff --name-only --diff-filter=ACMR "$base_ref"...HEAD`
- Exit 0 for clean, exit 1 for violations
- Test files are excluded from banned-pattern checks

**`generate-*` scripts** — setup generators:
- Generate scaffolding files for consuming repos (workflows, configs, baselines, badges)
- Idempotent — safe to re-run
- Write output to stdout or to files in the current directory

**Utilities** — `check-repo-structure.sh` validates directory layout, `filter-excludes.sh` filters file lists against exclusion patterns.

## Test Conventions

Tests in `test_patterns.sh` follow this structure:

```bash
echo "=== N. Description ==="

assert_matches  "pattern" "input that should match"    "test description"
assert_no_match "pattern" "input that should not match" "test description"
```

- Sections are numbered sequentially (1, 2, 3...) in their `=== N. ... ===` headers
- `assert_matches` / `assert_no_match` are defined at the top of the file
- `PASS`, `FAIL` and `TOTAL` are global counters shared by all sections
- The file ends with a total summary and exits 1 if any test failed
- E2E tests (end-to-end) create temporary git repos and run actual scripts

When adding tests: add a new numbered section, don't modify existing sections.

## Documentation Sync

These documents must stay consistent:

| Document | Scope |
|----------|-------|
| `README.md` | Workflow inputs, configs table, scripts table, project structure, quick-start examples |
| `docs/INTEGRATION.md` | Step-by-step setup instructions, generator scripts, troubleshooting |
| `docs/SDLC.md` | Lifecycle phases (pre-commit, PR gate, SAST, hardening) |
| `docs/ROADMAP.md` | Timeline of features, coding conventions |
| `configs/AGENTS.md` | Template for consuming repos — local verification commands, setup scripts |

When adding a check: update all relevant docs. When adding a script: add to README scripts table, AGENTS.md project structure, and any relevant docs.

## Local Testing Rule

**All C++ verification must run inside the project's Docker dev container — never on the host machine.** The Docker image must contain every tool and dependency needed to reproduce CI locally: compilers, clang-tidy, cppcheck, clang-format, cmake, IWYU, project dependencies, and headers. Never install these on the host. The container is the single source of truth.

- Run diff-aware scripts, builds, and tests inside the container
- Install all dependencies (apt packages, libraries, headers) in the Docker image — not on the host
- Search for dependencies and headers inside the container (not on the host filesystem)
- Only source code (volume-mounted) may be browsed/edited on the host
- Every CI check must be reproducible locally by running the same script inside the container
- Fuzz targets require Clang with `-fsanitize=fuzzer` — see `configs/ci-fuzz.yml` for the CI template

## Git & PR Rules

- **No AI attribution** — never add "Generated with Claude Code", "Co-Authored-By", or similar AI-generated footers to commit messages, PR descriptions, or any content
- **Conventional commits** — use `feat:`, `fix:`, `feat!:`, `BREAKING CHANGE:` prefixes (drives auto-release versioning)
- **Versioning** — first release is always `v0.0.1`, see `docs/VERSIONING.md`

## Don't

- Don't run C++ quality checks or tests on the host — always use the Docker dev container
- Don't change workflow input defaults from `false` to `true` — opt-in checks must stay opt-in
- Don't break backward compatibility on workflow inputs — existing callers must not break
- Don't modify existing test sections in `test_patterns.sh` — add new sections instead
- Don't hardcode paths — use workflow inputs for all paths
- Don't add AI attribution footers to commits, PRs, or code comments
