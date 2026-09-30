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

## 5. Read a failing check

The PR gets one comment per workflow, updated on every push. It lists each finding with file and line, and the same findings show as annotations on the diff. Fix them and push.

## 6. Suppress a false positive

Suppress in code so the PR reviews it. The per-tool syntax is in [Conventions](conventions.md#pr-gate). Do not suppress a check globally.
