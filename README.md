# Standard

[![Release](https://img.shields.io/github/v/release/PavelGuzenfeld/standard?label=version&color=blue&style=flat)](https://github.com/PavelGuzenfeld/standard/releases)
[![OpenSSF Scorecard](https://api.scorecard.dev/projects/github.com/PavelGuzenfeld/standard/badge)](https://scorecard.dev/viewer/?uri=github.com/PavelGuzenfeld/standard)
[![OpenSSF Best Practices](https://www.bestpractices.dev/projects/12012/badge)](https://www.bestpractices.dev/projects/12012)

Reusable GitHub Actions for C++ and Python quality gates. Only files changed in the PR are checked, so legacy code never blocks a merge.

## Why

C++ tools run inside your Docker image, so they see your toolchain, headers and `compile_commands.json`. Each workflow posts one summary comment on the PR and updates it on every push.

## Quick Start

C++:

```yaml
name: Quality
on:
  pull_request:
    branches: [main]

jobs:
  cpp:
    uses: PavelGuzenfeld/standard/.github/workflows/cpp-quality.yml@main
    with:
      docker_image: ghcr.io/your-org/your-dev-image:latest
    permissions:
      contents: read
      pull-requests: write
```

clang-tidy and cppcheck run by default. Everything else is opt-in.

Python:

```yaml
jobs:
  python:
    uses: PavelGuzenfeld/standard/.github/workflows/python-quality.yml@main
    permissions:
      contents: read
      pull-requests: write

  sast:
    uses: PavelGuzenfeld/standard/.github/workflows/sast-python.yml@main
    permissions:
      contents: read
      pull-requests: write
      security-events: write
```

To generate these files instead, see the [Quickstart](https://pavelguzenfeld.com/standard/CONSUMER-QUICKSTART/).

## With agent-sdlc

[agent-sdlc](https://github.com/PavelGuzenfeld/agent-sdlc) gates the coding agent's session and each commit. standard gates the PR. Do the standard setup first, then `mutation-gate rules sync`. The order, the `docs/` allowlist and the CI caveat are in [Integration](https://pavelguzenfeld.com/standard/INTEGRATION/#with-agent-sdlc).

## Documentation

Full docs: <https://pavelguzenfeld.com/standard/>. They cover every workflow input, the configs, the scripts and the `standard-ci` CLI. `standard-ci` supports Python 3.8 and newer.

## License

MIT License - see [LICENSE](LICENSE). Repo layout and contributor rules are in [AGENTS.md](AGENTS.md).
