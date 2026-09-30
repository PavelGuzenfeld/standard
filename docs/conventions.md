# Conventions

Enforced project-wide. A finding that matches a convention is handled by it, not tracked as a bug.

## Coding

- **Named parameters.** Mark unused ones `[[maybe_unused]]` instead of leaving them unnamed. Enforced by `readability-named-parameter`.
- **`fmt` for formatted I/O.** Replace `fscanf`, `fprintf`, `printf` and `sprintf`: `fmt::print(logfile, "{}\t{}\n", pts, pre);`. Needs `find_package(fmt REQUIRED)` and `fmt::fmt`.
- **Checked numeric casts.** Use `safe_cast<int>(container.size())`, not `static_cast`. Enforced by `bugprone-narrowing-conversions`.
- **GStreamer bindings.** Type-binding code is exempt from `cppcoreguidelines-pro-type-cstyle-cast`, `bugprone-casting-through-void`, `bugprone-assignment-in-if-condition` and `cppcoreguidelines-pro-type-vararg`, because the `GST_*` and `G_DEFINE_TYPE` macros trip them. Use `// NOLINT(check-name)` on those lines, never a global suppression.

## PR gate

Every check is a required status check, so findings are fixed before merge. In Settings > Branches, require `clang-format`, `clang-tidy`, `cppcheck` and `flawfinder`, and require branches to be up to date.

| Tool | False-positive suppression |
|------|----------------------------|
| clang-tidy | `// NOLINTNEXTLINE(check-name)` or `// NOLINT(check-name)` |
| cppcheck | Entry in `cppcheck.suppress` |
| flawfinder | `// Flawfinder: ignore` on the same line |
| clang-format | `// clang-format off` and `// clang-format on` |

## Full-codebase scan

For a legacy codebase or an audit, run inside the builder container:

```bash
find . -name '*.cpp' | xargs clang-tidy -p build/
cppcheck --enable=all --suppressions-list=cppcheck.suppress .
flawfinder --minlevel=2 --columns --context .
```
