# standard

Reusable GitHub Actions for C++ and Python quality gates. Only files changed in the PR are checked, so legacy code never blocks a merge.

C++ tools run inside your Docker image, so they see your toolchain, headers and `compile_commands.json`. Each workflow posts one summary comment on the PR.

```bash
pip install git+https://github.com/PavelGuzenfeld/standard.git
standard-ci init --preset recommended
```

Commit the generated workflows and the next PR runs the checks. [Usage](usage.md) has the steps.
