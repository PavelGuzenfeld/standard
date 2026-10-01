# Configs

Drop-in templates live in [`configs/`](https://github.com/PavelGuzenfeld/standard/tree/main/configs). Copy what you need into the repo root. [Integration](INTEGRATION.md#2-copy-configs) shows which files go where.

| Config | Purpose |
|--------|---------|
| [`.clang-tidy`](https://github.com/PavelGuzenfeld/standard/blob/main/configs/.clang-tidy) | clang-analyzer, cppcoreguidelines, modernize, bugprone, performance, readability |
| [`.clang-format`](https://github.com/PavelGuzenfeld/standard/blob/main/configs/.clang-format) | Standard Latest, 120-col, 4-space indent, Allman braces |
| [`.clang-tidy-naming`](https://github.com/PavelGuzenfeld/standard/blob/main/configs/.clang-tidy-naming) | snake_case functions, PascalCase types, trailing `_` private |
| [`eslint-naming.config.mjs`](https://github.com/PavelGuzenfeld/standard/blob/main/configs/eslint-naming.config.mjs) | TypeScript naming: snake_case, PascalCase types and .tsx components, no `I` prefix, trailing `_` private |
| [`cppcheck.suppress`](https://github.com/PavelGuzenfeld/standard/blob/main/configs/cppcheck.suppress) | Generic suppressions with vendor examples |
| [`naming-exceptions.txt`](https://github.com/PavelGuzenfeld/standard/blob/main/configs/naming-exceptions.txt) | File naming exceptions, one regex per line |
| [`.pre-commit-config.yaml`](https://github.com/PavelGuzenfeld/standard/blob/main/configs/.pre-commit-config.yaml) | clang-format, clang-tidy, cppcheck hooks |
| [`CMakePresets-sanitizers.json`](https://github.com/PavelGuzenfeld/standard/blob/main/configs/CMakePresets-sanitizers.json) | ASan, TSan, release-hardened presets |
| [`ci-multi-compiler.yml`](https://github.com/PavelGuzenfeld/standard/blob/main/configs/ci-multi-compiler.yml) | GCC-13 and Clang-21 matrix, ccache |
| [`ci-fuzz.yml`](https://github.com/PavelGuzenfeld/standard/blob/main/configs/ci-fuzz.yml) | Caller of `fuzz.yml` (ClusterFuzzLite) |
| [`ci-codeql.yml`](https://github.com/PavelGuzenfeld/standard/blob/main/configs/ci-codeql.yml) | CodeQL for C++ and Python |
| [`ci-infer.yml`](https://github.com/PavelGuzenfeld/standard/blob/main/configs/ci-infer.yml) | Infer: Pulse, InferBO, RacerD |
| [`cmake-warnings.cmake`](https://github.com/PavelGuzenfeld/standard/blob/main/configs/cmake-warnings.cmake) | `-Wall -Wextra -Wpedantic -Werror` plus extras |
| [`test-checklist.md`](https://github.com/PavelGuzenfeld/standard/blob/main/configs/test-checklist.md) | Test edge case checklist |
| [`repo-structure-ros2.txt`](https://github.com/PavelGuzenfeld/standard/blob/main/configs/repo-structure-ros2.txt) | ROS2 package structure template |
| `repo-structure-{python,cmake-cpp,typescript,godot}.txt` | Structure templates for other project types |
| [`AGENTS.md`](https://github.com/PavelGuzenfeld/standard/blob/main/configs/AGENTS.md) | Agent instructions template for consuming projects |
| [`SECURITY.md`](https://github.com/PavelGuzenfeld/standard/blob/main/configs/SECURITY.md) | Security policy template |
| [`dependabot.yml`](https://github.com/PavelGuzenfeld/standard/blob/main/configs/dependabot.yml) | Dependabot template |
| [`gdlintrc`](https://github.com/PavelGuzenfeld/standard/blob/main/configs/gdlintrc) | GDScript naming rules for gdlint |
