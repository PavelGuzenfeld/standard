# Conventions and Roadmap

What each workflow runs is listed in the [README](../README.md#reusable-workflows) and [SDLC](SDLC.md). This page holds the coding conventions and what is still open.

## Coding Conventions

These are enforced project-wide. A finding that matches one is handled by the convention, not tracked as a bug.

**Named parameters.** Every function parameter is named. Mark intentionally unused ones `[[maybe_unused]]` instead of leaving them unnamed: `void callback([[maybe_unused]] int event_id, const std::string& message);`. Enforced by `readability-named-parameter`.

**`fmt` for formatted I/O.** Replace `fscanf`, `fprintf`, `printf` and `sprintf` with `fmt`: `fmt::print(logfile, "{}\t{}\t{}\n", pts, pre, post);` needs `find_package(fmt REQUIRED)` and `target_link_libraries(... fmt::fmt)`.

**Checked numeric casts.** Narrowing conversions use a checked cast that validates the value fits at runtime: `int count = safe_cast<int>(container.size());` instead of `static_cast`. Enforced by `bugprone-narrowing-conversions`.

**GStreamer bindings.** Code that implements GStreamer type bindings (element registration, pad templates, signal handlers, cast macros) is exempt from these checks:

- `cppcoreguidelines-pro-type-cstyle-cast`: `GST_ELEMENT_CAST` and `GST_PAD_CAST` expand to C-style casts
- `bugprone-casting-through-void`: `G_DEFINE_TYPE` and type-check macros cast through `void*`
- `bugprone-assignment-in-if-condition`: `GST_*` macros assign in conditions
- `cppcoreguidelines-pro-type-vararg`: property and signal APIs are variadic

Use `// NOLINT(check-name)` on those lines. Do not suppress the checks globally.

## PR Gate

All checks run as required status checks. A PR cannot merge until they pass, so findings are fixed before they enter the codebase instead of being ticketed.

Branch protection (Settings > Branches):

- Require status checks to pass before merging, with required checks `clang-format`, `clang-tidy`, `cppcheck`, `flawfinder`
- Require branches to be up to date, so checks run against the latest base

False positives are suppressed in code and reviewed with the PR:

| Tool | Suppression |
|------|-------------|
| clang-tidy | `// NOLINTNEXTLINE(check-name)` or `// NOLINT(check-name)` |
| cppcheck | Entry in `cppcheck.suppress` |
| flawfinder | `// Flawfinder: ignore` on the same line |
| clang-format | `// clang-format off` and `// clang-format on` |

## Full-Codebase Scan

For onboarding a legacy codebase or a periodic audit, scan everything from inside the builder container:

```bash
find . -name '*.cpp' | xargs clang-tidy -p build/
cppcheck --enable=all --suppressions-list=cppcheck.suppress .
flawfinder --minlevel=2 --columns --context .
```

## Open Items

| Item | Priority | Note |
|------|----------|------|
| ClusterFuzzLite as a reusable workflow | Medium | `ci-fuzz.yml` exists as a template, not `workflow_call` |
| Renovate support in `generate-workflow.sh` | Low | Handles Conan, which Dependabot does not |
| BinSkim for richer binary checks | Low | The `readelf` hardening job covers the essentials. BinSkim adds stack-clash protection and SafeStack |
| Copy-paste detection (jscpd) | Low | Finds smells, not bugs, and is noisy |
