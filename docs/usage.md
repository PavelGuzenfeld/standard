# Usage

From a bare repo to a failing check you can read.

## 1. Opt a repo in

Install `standard-ci`, run `standard-ci init`, then commit and push. The [Quickstart](CONSUMER-QUICKSTART.md) has the commands and lists the presets.

## 2. Call the workflows

The [README Quick Start](https://github.com/PavelGuzenfeld/standard/blob/main/README.md#quick-start) has the C++ and Python workflow YAML. clang-tidy and cppcheck run by default. Turn the rest on one at a time; [Integration](INTEGRATION.md#3-enable-checks-one-at-a-time) shows how. Add `sast-python.yml` for Semgrep, pip-audit and CodeQL. Inputs are in [Workflows](workflows/index.md).

## 3. Run the checks locally

The `diff-*.sh` scripts check only what changed against a base branch. Run them in the project's dev container:

```bash
./scripts/diff-clang-tidy.sh origin/main build "cpp hpp h"
./scripts/diff-cppcheck.sh origin/main
./scripts/diff-clang-format.sh origin/main "cpp hpp h"
```

Arguments, env vars and the generators are in [Scripts](scripts.md).

## 4. Read a failing check

The PR gets one comment per workflow, updated on every push. It lists each finding with file and line, and the same findings show as annotations on the diff. Fix them and push.

## 5. Suppress a false positive

Suppress in code so the PR reviews it. The per-tool syntax is in [Conventions](conventions.md#pr-gate). Do not suppress a check globally.
