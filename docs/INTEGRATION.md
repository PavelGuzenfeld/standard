# Integration Guide

Quick-start workflow files are in the [README](../README.md#quick-start). Every input and default is in [Workflow Inputs](../README.md#workflow-inputs).

## Generators

```bash
./scripts/generate-workflow.sh
./scripts/generate-agents-md.sh
./scripts/install-hooks.sh
./scripts/generate-baseline.sh
./scripts/generate-badges.sh
```

They write workflow files, an `AGENTS.md`, git hooks, baseline files and badge markdown. They are idempotent, so re-run them as you enable more checks. The steps below are the manual route.

## C++ Setup

### 1. Docker image

All C++ checks and tests run inside your Docker dev container, in CI and locally. The image is the single source of truth. Every CI check must be reproducible by running the same script in the container.

The image needs:

- clang-tidy (14+ recommended)
- cppcheck (2.10+ recommended)
- clang-format, if `enable_clang_format: true`
- cmake and a build toolchain
- project dependencies (libraries, headers, ROS2 packages)
- `compile_commands.json` at `compile_commands_path`

The repo is mounted at `source_mount` (default `/workspace/src`). A non-root user in the image needs read access to that mount.

### 2. Copy configs

Copy what you need from [`configs/`](../configs/) into the repo root:

```bash
cp configs/.clang-tidy .clang-tidy
cp configs/.clang-format .clang-format
cp configs/cppcheck.suppress cppcheck.suppress
cp configs/.clang-tidy-naming .clang-tidy-naming
cp configs/naming-exceptions.txt naming-exceptions.txt
```

`.clang-tidy` is required. The rest are optional. The workflow uses your config when a config input points at it, and the tool defaults otherwise. Config inputs take paths relative to the repo root:

```yaml
with:
  clang_tidy_config: .clang-tidy
  cppcheck_suppress: tools/cppcheck.suppress
  clang_format_config: .clang-format
  file_naming_exceptions: tools/naming-exceptions.txt
```

### 3. Enable checks one at a time

Start with the defaults (clang-tidy, cppcheck) and add checks as the codebase is ready:

```yaml
jobs:
  cpp:
    uses: PavelGuzenfeld/standard/.github/workflows/cpp-quality.yml@main
    with:
      docker_image: ghcr.io/your-org/your-image:latest
      cppcheck_include_file: cppcheck.include
      cppcheck_suppress: cppcheck.suppress
      enable_clang_format: true
      enable_file_naming: true
      ban_cout: true
      ban_new: true
      enforce_doctest: true
      enable_flawfinder: true
      enable_sarif: true
      enable_hardening: true
    permissions:
      contents: read
      pull-requests: write
      security-events: write
```

`security-events: write` is needed for SARIF upload. The sanitizer, TSan, coverage and IWYU jobs each take an `enable_*` flag and a script input, listed in the README.

### 4. SAST

CodeQL and Infer are templates: copy [`configs/ci-codeql.yml`](../configs/ci-codeql.yml) or [`configs/ci-infer.yml`](../configs/ci-infer.yml) to `.github/workflows/`. CodeQL runs on push, PR and weekly. Infer runs on push to main.

### 5. Agent instructions

```bash
cp configs/AGENTS.md AGENTS.md
```

Edit the "Opt-in" section to match the checks you enabled.

### 6. Copilot code review

```bash
cp configs/.github/copilot-instructions.md .github/copilot-instructions.md
mkdir -p .github/instructions
cp configs/.github/instructions/cpp.instructions.md .github/instructions/
cp configs/.github/instructions/python.instructions.md .github/instructions/
```

The files use `applyTo` frontmatter, so each language file applies only to its own files. Drop the one you do not need. Turn on the reviewer under Settings > Copilot > Code review, or request `@copilot` on a PR. See [GitHub's custom instructions guide](https://docs.github.com/en/copilot/tutorials/use-custom-instructions).

### 7. Pre-commit hooks

```bash
./scripts/install-hooks.sh
```

Or by hand:

```bash
cp configs/.pre-commit-config.yaml .pre-commit-config.yaml
pip install pre-commit
pre-commit install
```

### 8. CMake presets and warnings

```bash
cp configs/CMakePresets-sanitizers.json CMakePresets.json
cp configs/cmake-warnings.cmake cmake/cmake-warnings.cmake
```

```cmake
include(cmake/cmake-warnings.cmake)
target_link_libraries(my_target PRIVATE warnings)
```

Presets and flags are described in [SDLC](SDLC.md#cmake-presets-for-sanitizer-builds).

### 9. Fuzzing

```bash
cp configs/ci-fuzz.yml .github/workflows/fuzz.yml
```

Set `matrix.target` to your fuzz target names, for example `[parse_input, decode_frame]`. Put harnesses in `fuzz_targets/`:

```cpp
extern "C" int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
    my_parser(data, size);
    return 0;
}
```

Gate the targets in `CMakeLists.txt`:

```cmake
option(ENABLE_FUZZING "Build fuzz targets" OFF)
if(ENABLE_FUZZING)
    add_executable(parse_input fuzz_targets/parse_input.cpp)
    target_link_libraries(parse_input PRIVATE my_library -fsanitize=fuzzer)
endif()
```

The template runs libFuzzer with ASan/UBSan, caches the corpus, uploads crash artifacts, and triggers on PRs and weekly.

## Python Setup

```yaml
jobs:
  python:
    uses: PavelGuzenfeld/standard/.github/workflows/python-quality.yml@main
    with:
      python_linter: ruff
      fail_under: 80
    permissions:
      contents: read
      pull-requests: write

  sast:
    uses: PavelGuzenfeld/standard/.github/workflows/sast-python.yml@main
    with:
      enable_codeql: true
    permissions:
      contents: read
      pull-requests: write
      security-events: write
```

Use `python_linter: flake8` for ROS2/ament. `fail_under` defaults to 100, meaning zero violations on changed lines. `ruff_select` overrides `select` and `ignore` in `pyproject.toml`. Extra Semgrep rule sets go in `semgrep_rules`, for example `'p/python p/owasp-top-ten p/django'`.

```toml
[tool.ruff]
target-version = "py38"
line-length = 88
```

## Customization

### cppcheck include file

`cppcheck.include` lists one include directory per line. Blank lines are ignored.

```
/opt/ros/humble/include
/opt/ros/humble/include/rclcpp
src/my_package/include
```

### Exclusion file

`.standards-exclude` lists path prefixes to skip, one per line, for vendored code, submodules and build output. All checks respect it.

```
vendor/httplib.h
external_sdk/
build/
install/
```

```yaml
with:
  exclude_file: .standards-exclude
```

### File naming exceptions

One regex per line, matched against path segments.

```
vendor
third_party
.*_generated
Gems
Code
```

### Package naming

C++ packages follow `include/<package_name>/` with a snake_case name. `enable_file_naming: true` checks every path segment. `include/nav_utils/` passes. `include/NavUtils/` and `include/flightController/` fail.

### ROS2 and colcon

If the image already has `compile_commands.json`:

```yaml
with:
  docker_image: ghcr.io/your-org/ros2-dev:humble
  source_setup: 'source /opt/ros/humble/install/setup.bash'
  compile_commands_path: build/your_package
  cppcheck_include_file: cppcheck.include
  runner: '"self-hosted"'
```

If CI must build it, use a pre-analysis script and a build cache:

```yaml
with:
  docker_image: ghcr.io/your-org/ros2-dev:humble
  source_setup: 'source /opt/ros/humble/setup.bash'
  compile_commands_path: build
  pre_analysis_script: .github/scripts/pre-analysis.sh
  build_cache_key: clang-tidy-build-${{ hashFiles('**/CMakeLists.txt', '**/package.xml') }}
  runner: '"self-hosted"'
```

`.github/scripts/pre-analysis.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
colcon build \
  --cmake-args -DCMAKE_BUILD_TYPE=Release -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
  --event-handlers console_cohesion+
python3 -c "
import json, glob
merged, seen = [], set()
for f in sorted(glob.glob('build/*/compile_commands.json')):
    for entry in json.load(open(f)):
        key = entry.get('file', '')
        if key not in seen:
            seen.add(key)
            merged.append(entry)
json.dump(merged, open('build/compile_commands.json', 'w'), indent=2)
"
```

On a cache hit only changed packages rebuild.

### Self-hosted runners

`runner` takes a JSON string or array on every workflow: `runner: '"self-hosted"'`.

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| "No C++ files changed" | Default extensions are `cpp hpp h cc cxx`. Set `file_extensions: 'cpp hpp h cc cxx c'` to add more. |
| clang-tidy: "compile_commands.json not found" | `compile_commands_path` is a directory inside the container, relative to `source_mount`. For `/workspace/src/build/my_pkg/compile_commands.json` use `build/my_pkg`. |
| cppcheck: "file not found" for system headers | Set `cppcheck_includes` or `cppcheck_include_file`. |
| PR comments missing | Add `pull-requests: write`. SARIF upload also needs `security-events: write`. |
| diff-quality too strict | Lower `fail_under` (default 100). 80 allows a 20% violation rate on changed lines. |
| Hardening: "No ELF binaries found" | Set `hardening_binary_paths` (default `build-hardened/bin/*`), for example `'build-hardened/bin/* build-hardened/lib/*.so'`. A custom `hardening_script` must write binaries to those paths. |

## Auto-Release

`auto-release.yml` bumps the version on every push to `main` from conventional commit prefixes. It creates an annotated git tag and a GitHub Release with generated notes, and optionally a SLSA provenance attestation. No commit is made to `main`, so there is no loop. The git tag is the version of record.

`.github/workflows/release.yml`:

```yaml
name: Release
on:
  push:
    branches: [main]

permissions:
  contents: write
  id-token: write
  attestations: write

jobs:
  release:
    uses: PavelGuzenfeld/standard/.github/workflows/auto-release.yml@main
    with:
      enable_provenance: true
```

`enable_provenance` defaults to `false`. When true it attests each release with `actions/attest-build-provenance`. `default_bump` (default `patch`) applies when no prefix matches. Optional secrets `app_id` and `app_private_key` (GitHub App credentials): when both are set, release events trigger downstream workflows.

The workflow finds the latest tag with `git tag -l 'v*' --sort=-v:refname`, scans commits since it, and takes the highest bump. With no `v*` tag the first release is `v0.0.1`.

| Prefix | Example | Bump |
|--------|---------|------|
| `feat!:` or `BREAKING CHANGE:` | `feat!: redesign API` | major |
| `feat:` or `feat(scope):` | `feat(auth): add OAuth` | minor |
| Anything else | `fix: null pointer` | patch |

## Security Hygiene

These steps raise your OpenSSF Scorecard score.

```bash
cp configs/SECURITY.md SECURITY.md
mkdir -p .github
cp configs/dependabot.yml .github/dependabot.yml
```

Fill the `TODO` placeholders in `SECURITY.md` with a contact and response times. The Dependabot template watches `github-actions`. Uncomment `pip`, `npm`, `cargo` or `docker` as needed.

Add these to your infra-lint workflow call:

```yaml
with:
  enable_dangerous_workflows: true
  enable_binary_artifacts: true
  enable_gitleaks: true
  gitleaks_config: .gitleaks.toml
```

- Dangerous workflows: flags `pull_request_target` misuse and injection such as `${{ github.event.pull_request.title }}` in `run:` steps. Locally: `./scripts/check-dangerous-workflows.sh .github/workflows/`.
- Binary artifacts: flags committed `.exe`, `.dll`, `.so`, `.jar`, `.pyc`, `.whl` and similar.
- Gitleaks: scans only the commits in the PR range. Add allowlists in `.gitleaks.toml`:

```toml
[allowlist]
  paths = [
    '''tests/fixtures/.*''',
    '''docs/examples/.*''',
  ]
```

### Allstar

[Allstar](https://github.com/ossf/allstar) enforces GitHub platform settings (branch protection, collaborator access) from config files. This repo's workflows check code. The two complement each other. Install the [Allstar app](https://github.com/apps/allstar-app) first.

Per repo:

```bash
mkdir -p .allstar
cp configs/.allstar/*.yaml .allstar/
```

| Policy | Enforces |
|--------|----------|
| `branch_protection.yaml` | PR approvals, no force push, dismiss stale reviews |
| `security.yaml` | `SECURITY.md` exists |
| `binary_artifacts.yaml` | No committed binaries |
| `dangerous_workflow.yaml` | No `pull_request_target` injection |
| `outside.yaml` | No admin access for outside collaborators |
| `actions.yaml` | Required or denied GitHub Actions |

Org-wide: create a repo named `.allstar` in the org and copy `configs/.allstar/*.yaml` into it. In `allstar.yaml`, comment out `optIn` and set:

```yaml
optConfig:
  optOutStrategy: true
  optOutArchivedRepos: true
  optOutForkedRepos: true
```

In `branch_protection.yaml`, set `action: fix` to configure branch protection instead of only opening issues.

## Trend Dashboard

`trend-dashboard.yml` queries the GitHub Actions API for the last `lookback_days` days of runs of the standard workflows it finds in the repo. It buckets job results by week and writes a table of pass rates with trend arrows to the workflow summary. Inputs are in the [README](../README.md#workflow-inputs).

`.github/workflows/trends.yml`:

```yaml
name: Trend Dashboard
on:
  schedule:
    - cron: '0 9 * * 1'
  workflow_dispatch:

jobs:
  trends:
    uses: PavelGuzenfeld/standard/.github/workflows/trend-dashboard.yml@main
    with:
      slack_webhook_url: ${{ secrets.SLACK_TRENDS_WEBHOOK }}
      post_to_discussions: true
    permissions:
      actions: read
      contents: read
      discussions: write
```

Drop `slack_webhook_url` to skip Slack. Drop `post_to_discussions` and `discussions: write` to skip Discussions.
