# Usage

From a bare repo to a failing check you can read.

## 1. Opt a repo in

Install `standard-ci`, run `standard-ci init`, then commit and push. The [Quickstart](CONSUMER-QUICKSTART.md) has the commands and lists the presets.

## 2. Call the workflows

The [README Quick Start](https://github.com/PavelGuzenfeld/standard/blob/main/README.md#quick-start) has the C++ and Python workflow YAML. clang-tidy and cppcheck run by default. Turn the rest on one at a time; [Integration](INTEGRATION.md#3-enable-checks-one-at-a-time) shows how. Add `sast-python.yml` for Semgrep, pip-audit and CodeQL. Inputs are in [Workflows and inputs](workflows.md).

## 3. Run the checks locally

The `diff-*.sh` scripts check only what changed against a base branch. Run them in the project's dev container:

```bash
./scripts/diff-clang-tidy.sh origin/main build "cpp hpp h"
./scripts/diff-cppcheck.sh origin/main
./scripts/diff-clang-format.sh origin/main "cpp hpp h"
```

Every script prints its usage with `--help`.

| Script | Arguments | Purpose |
|---|---|---|
| `diff-clang-tidy.sh` | `<base> <compile_commands_dir> [extensions]` | clang-tidy on changed files |
| `diff-cppcheck.sh` | `<base>` | cppcheck on changed files. Env: `CPPCHECK_SUPPRESS`, `CPPCHECK_INCLUDES`, `CPPCHECK_STD`, `CPPCHECK_EXTENSIONS` |
| `diff-clang-format.sh` | `<base> [extensions]` | clang-format check on changed files. Env: `CLANG_FORMAT_CONFIG` |
| `diff-iwyu.sh` | `<base> <compile_commands_dir> [extensions] [mapping_file] [--strict]` | include-what-you-use on changed files. Reports only, unless `--strict` |
| `diff-file-naming.sh` | `<base> [exceptions_file]` | snake_case file and directory names in the diff. Env: `NAMING_ALLOWED_PREFIXES` |
| `diff-ts-naming.sh` | `<base> [extensions]` | typescript-eslint naming rules on changed `.ts` and `.tsx`. Env: `TS_NAMING_CONFIG` |
| `diff-gdlint.sh` | `<base> [config_file]` | gdlint naming rules on changed `.gd` files |
| `diff-test-mirror.sh` | `<base>` | each newly added file under `src/` has a mirrored test under `tests/`. Env: `MIRROR_*` |
| `check-dangerous-workflows.sh` | `[workflows_dir]` | `pull_request_target` with a PR head checkout, and PR, issue or comment text inside `run:` |
| `check-layering.sh` | `[root_dir]` | runs the contract it finds: `.importlinter`, a dependency-cruiser config or `.layers`. Skips if none. Env: `DEPCRUISE_TARGET` |
| `check-repo-structure.sh` | `<config_file> [root_dir]` | required and optional files and folders named in the config |
| `check-hardening.sh` | `<path_or_glob>... [--skip check]...` | ELF hardening via readelf: pie, relro, bindnow, canary, fortify, nx, cet |
| `filter-excludes.sh` | `[exclude_file] [file_list]` | rewrites `file_list` in place, dropping paths that start with an exclude prefix |
| `generate-baseline.sh` | `<cppcheck\|file-naming\|clang-format\|flawfinder> [options]` | write a baseline or suppression file for incremental adoption |
| `generate-workflow.sh` | `[--output-dir PATH] [--non-interactive] [--dependency-bot dependabot\|renovate\|both]` | write the quality workflows to `.github/workflows/`. `--dependency-bot` also writes `dependabot.yml` and `renovate.json` (Conan manager) beside them |
| `generate-agents-md.sh` | `[--output PATH] [--non-interactive]` | write AGENTS.md |
| `generate-badges.sh` | `[--scan-workflows\|--interactive] [--format markdown\|html]` | print README badge markup to stdout |
| `install-hooks.sh` | `[--force] [--uninstall]` | install a git pre-commit hook that runs the diff scripts. `--force` if `.pre-commit-config.yaml` exists |

## 4. Read a failing check

The PR gets one comment per workflow, updated on every push. It lists each finding with file and line, and the same findings show as annotations on the diff. Fix them and push.

## 5. Suppress a false positive

Suppress in code so the PR reviews it. The per-tool syntax is in [Conventions](conventions.md#pr-gate). Do not suppress a check globally.
