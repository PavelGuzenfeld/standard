# Agent Instructions

Reusable GitHub Actions workflows for diff-aware C++ and Python quality gates. Only changed files are checked.

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

`test_patterns.sh` validates the grep/regex patterns the workflow jobs and scripts use. Every assertion must pass.

## Adding a New Check

1. Workflow job: add a job in `cpp-quality.yml` or `python-quality.yml` with an `enable_*` or `ban_*` input, default `false` for opt-in checks.
2. Script, if needed: `scripts/diff-<name>.sh` for the diff-aware logic.
3. Config, if needed: a template in `configs/`.
4. Tests: a new numbered section in `tests/test_patterns.sh`.
5. Docs: README (inputs, configs, scripts tables), `docs/INTEGRATION.md` (setup), `docs/SDLC.md` (lifecycle phases). A new script also goes in the README scripts table and the structure above.

Always-on jobs are `clang-tidy` and `cppcheck`. Opt-in jobs are gated by a boolean input defaulting to `false`. Jobs post annotations with `::warning file=...`. The `summary` job collects results into one PR comment.

### Scripts

`diff-*` scripts take `base_ref` as the first argument (for example `origin/main`), find changed files with `git diff --name-only --diff-filter=ACMR "$base_ref"...HEAD`, exit 0 when clean and 1 on violations, and exclude test files from banned-pattern checks.

`generate-*` scripts write scaffolding for consuming repos to stdout or the current directory, and are idempotent.

`check-repo-structure.sh` validates directory layout. `filter-excludes.sh` filters file lists against exclusion patterns.

### Tests

```bash
echo "=== N. Description ==="

assert_matches  "pattern" "input that should match"    "test description"
assert_no_match "pattern" "input that should not match" "test description"
```

- Sections are numbered sequentially in their `=== N. ... ===` headers.
- `assert_matches` and `assert_no_match` are defined at the top of the file.
- `PASS`, `FAIL` and `TOTAL` are global counters. The file ends with a summary and exits 1 on any failure.
- End-to-end tests create temporary git repos and run the real scripts.
- Add a new numbered section. Do not modify existing ones.

## Local Testing

All C++ verification runs inside the project's Docker dev container, never on the host. The image holds every tool and dependency needed to reproduce CI: compilers, clang-tidy, cppcheck, clang-format, cmake, IWYU, project libraries and headers. Search for headers inside the container. Only the volume-mounted source is edited on the host. Fuzz targets need Clang with `-fsanitize=fuzzer`, see `configs/ci-fuzz.yml`.

## Git and PRs

- No AI attribution: no "Generated with Claude Code", "Co-Authored-By" or similar footer in commits, PR descriptions or code comments.
- Conventional commits: `feat:`, `fix:`, `feat!:`, `BREAKING CHANGE:` drive auto-release versioning.
- The first release is `v0.0.1`. See [Versioning](docs/VERSIONING.md).

## Don't

- Don't change a workflow input default from `false` to `true`. Opt-in checks stay opt-in.
- Don't break backward compatibility on workflow inputs.
- Don't modify existing test sections in `test_patterns.sh`.
- Don't hardcode paths. Use workflow inputs.
