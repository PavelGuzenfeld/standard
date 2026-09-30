# Usage

From a bare repo to a failing check you can read.

## 1. Opt a repo in

```bash
pip install git+https://github.com/PavelGuzenfeld/standard.git
cd your-repo
standard-ci init --preset recommended
```

It writes the workflows for the languages it detects and `.standard.yml`. Commit and push. [Quickstart](CONSUMER-QUICKSTART.md) lists the presets.

## 2. C++

Call the workflow with your build image:

```yaml
jobs:
  cpp:
    uses: PavelGuzenfeld/standard/.github/workflows/cpp-quality.yml@main
    with:
      docker_image: ghcr.io/your-org/your-dev-image:latest
    permissions:
      contents: read
      pull-requests: write
```

clang-tidy and cppcheck run by default. Turn the rest on one at a time; [Integration](INTEGRATION.md#3-enable-checks-one-at-a-time) shows how.

## 3. Python

```yaml
jobs:
  python:
    uses: PavelGuzenfeld/standard/.github/workflows/python-quality.yml@main
    permissions:
      contents: read
      pull-requests: write
```

Add `sast-python.yml` for Semgrep, pip-audit and CodeQL. Inputs are in [Workflows and inputs](workflows.md).

## 4. Run the checks locally

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
| `diff-cppcheck.sh` | `<base>` | cppcheck on changed files |
| `diff-clang-format.sh` | `<base> [extensions]` | clang-format on changed files |
| `diff-iwyu.sh` | `<base> <compile_commands_dir> [extensions] [mapping_file]` | include-what-you-use on changed files |
| `diff-file-naming.sh` | `<base> [exceptions_file]` | snake_case names in the diff |
| `diff-ts-naming.sh` | `<base> [extensions]` | TypeScript naming in the diff |
| `diff-gdlint.sh` | `<base> [config_file]` | gdlint on changed `.gd` files |
| `diff-test-mirror.sh` | `<base>` | every new source file has a test |
| `check-dangerous-workflows.sh` | `[workflows_dir]` | unsafe workflow patterns |
| `check-layering.sh` | `[root_dir]` | import layers from `.layers` |
| `check-repo-structure.sh` | `<config_file> [root_dir]` | required files and folders |
| `check-hardening.sh` | `<path>... [--skip check]...` | ELF hardening flags |
| `filter-excludes.sh` | `[exclude_file] [file_list]` | drop excluded paths from a list |
| `generate-baseline.sh` | `<tool> [options]` | write a baseline for incremental adoption |
| `generate-workflow.sh` | `[--output-dir PATH] [--non-interactive]` | write workflows |
| `generate-agents-md.sh` | `[--output PATH] [--non-interactive]` | write AGENTS.md |
| `generate-badges.sh` | `[--scan-workflows] [--interactive] [--format markdown\|html]` | write README badges |
| `install-hooks.sh` | `[--force] [--uninstall]` | install git hooks |

## 5. Read a failing check

The PR gets one comment per workflow, updated on every push. It lists each finding with file and line, and the same findings show as annotations on the diff. Fix them and push.

## 6. Suppress a false positive

Suppress in code so the PR reviews it. The per-tool syntax is in [Conventions](conventions.md#pr-gate). Do not suppress a check globally.
