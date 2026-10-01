# Scripts

Diff-aware checks run the CI logic on files changed against a base branch. Run them in the project's dev container. Every script prints its usage with `--help`.

| Script | Arguments | Purpose |
|---|---|---|
| `diff-clang-tidy.sh` | `<base> <compile_commands_dir> [extensions]` | clang-tidy on changed files |
| `diff-cppcheck.sh` | `<base>` | cppcheck on changed files. Env: `CPPCHECK_SUPPRESS`, `CPPCHECK_INCLUDES`, `CPPCHECK_STD`, `CPPCHECK_EXTENSIONS` |
| `diff-clang-format.sh` | `<base> [extensions]` | clang-format check on changed files. Env: `CLANG_FORMAT_CONFIG` |
| `diff-iwyu.sh` | `<base> <compile_commands_dir> [extensions] [mapping_file] [--strict]` | include-what-you-use on changed files. Reports only, unless `--strict` |
| `diff-file-naming.sh` | `<base> [exceptions_file]` | snake_case file and directory names in the diff. Env: `NAMING_ALLOWED_PREFIXES` |
| `diff-ts-naming.sh` | `<base> [extensions]` | typescript-eslint naming-convention on changed `.ts` and `.tsx`. Needs `eslint-naming.config.mjs`, eslint and typescript-eslint. Env: `TS_NAMING_CONFIG` |
| `diff-gdlint.sh` | `<base> [config_file]` | GDScript naming (gdlint) on changed `.gd` files |
| `diff-jscpd.sh` | `<base> [threshold_percent] [extensions] [--strict]` | jscpd copy-paste detection on changed files. Reports only, unless `--strict`. Env: `JSCPD_BIN` |
| `diff-test-mirror.sh` | `<base>` | each newly added file under `src/` has a mirrored test under `tests/`. Env: `MIRROR_*` |
| `check-dangerous-workflows.sh` | `[workflows_dir]` | `pull_request_target` with a PR head checkout, and PR, issue or comment text inside `run:`. Audits workflow files for injection patterns |
| `check-layering.sh` | `[root_dir]` | runs the repo's layering contract: `.importlinter`, a dependency-cruiser config (`.dependency-cruiser.cjs`) or `.layers` for C++ and GDScript. Skips if none. Env: `DEPCRUISE_TARGET` |
| `check-repo-structure.sh` | `<config_file> [root_dir]` | validate directory structure against a template: required and optional files and folders named in the config |
| `check-hardening.sh` | `<path_or_glob>... [--skip check]...` | ELF hardening via readelf: pie, relro, bindnow, canary, fortify, nx, cet |
| `filter-excludes.sh` | `[exclude_file] [file_list]` | rewrites `file_list` in place, dropping paths that start with an exclude prefix |
| `generate-baseline.sh` | `<cppcheck\|file-naming\|clang-format\|flawfinder> [options]` | write suppression and baseline files for incremental adoption |
| `generate-workflow.sh` | `[--output-dir PATH] [--non-interactive] [--dependency-bot dependabot\|renovate\|both]` | write the quality workflows to `.github/workflows/`. `--dependency-bot` also writes `dependabot.yml` and `renovate.json` (Conan manager) beside them |
| `generate-agents-md.sh` | `[--output PATH] [--non-interactive]` | write a tailored AGENTS.md |
| `generate-badges.sh` | `[--scan-workflows\|--interactive] [--format markdown\|html]` | print README badge markup to stdout |
| `install-hooks.sh` | `[--force] [--uninstall]` | install a git pre-commit hook that runs the diff scripts. `--force` if `.pre-commit-config.yaml` exists |

## Examples

```bash
./scripts/diff-clang-tidy.sh origin/main build "cpp hpp h"
./scripts/diff-cppcheck.sh origin/main
./scripts/diff-clang-format.sh origin/main "cpp hpp h"
./scripts/diff-file-naming.sh origin/main naming-exceptions.txt
./scripts/diff-iwyu.sh origin/main build
./scripts/check-repo-structure.sh configs/repo-structure-ros2.txt .
./scripts/check-hardening.sh build-hardened/bin/*
```

## Layering and TypeScript naming

`.layers` lists directories lowest layer first, one per line. A lower layer may not `#include` or `preload`/`load` a higher one, and cycles fail. Use it as `PavelGuzenfeld/standard/actions/layering@main`.

TypeScript naming runs as `PavelGuzenfeld/standard/actions/ts-naming@main`: typescript-eslint on changed `.ts`/`.tsx` with `eslint-naming.config.mjs`.
