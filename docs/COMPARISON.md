# Comparison with Other Tools (Feb 2026)

No aggregator runs serious C++ analysis in one opt-in reusable workflow, because that needs a compilation database and the project's build environment. MegaLinter, Super-Linter, trunk and pre-commit.ci run tools without build context, so they cannot use clang-tidy's semantic analysis. `standard` runs inside the caller's Docker image with their `compile_commands.json`. What it provides is in the [README](../README.md#reusable-workflows).

## Competitors Compared

### Meta-Linters / Aggregators

| Tool | Strengths vs standard | Weaknesses vs standard |
|------|----------------------|----------------------|
| **MegaLinter** (OX Security) | 100+ linters, 50+ languages, auto-fix PRs, CI-agnostic, 4 secrets detectors (gitleaks/trufflehog/secretlint/devskim), trivy SBOM, copy-paste detection | **No clang-tidy**, no compilation-database analysis, no builds/tests, no sanitizers, no coverage, no auto-release. Only 3 C++ linters (cppcheck, cpplint, clang-format) |
| **Super-Linter** v8.5 | 70+ languages, parallel execution, GitHub-native | Only 2 C++ linters (cpplint + clang-format). No cppcheck, no clang-tidy, no security, no SBOM |
| **Trunk Check** | Hermetic tool management, hold-the-line, clang-tidy support | **Web dashboard shut down July 2025.** Company pivoted to CI reliability. Code quality is maintenance-mode. Closed-source CLI binary |
| **Reviewdog** | Universal adapter for any linter output, PR annotations | Not a framework — must wire each tool separately |
| **pre-commit.ci** | Zero-config from .pre-commit-config.yaml, auto-fix commits, weekly hook updates | **No Docker hooks** (blocks most C++ tools), no security/SBOM, GitHub only, cannot use compilation databases |

### C++ Project Templates

| Tool | Strengths vs standard | Weaknesses vs standard |
|------|----------------------|----------------------|
| **cmake_template (Jason Turner)** | Multi-OS (Win/Mac/Linux), MSVC, WASM builds, Catch2 fuzz testing, CMakePresets, actively maintained (Feb 2026) | **Not reusable** (fork-per-project, diverges), no diff-awareness, no SBOM, no auto-release, no PR annotations, no secrets detection, no Python |
| **aminya/project_options** | Only truly reusable CMake module (FetchContent), 30+ flags, hardening, sanitizers, IWYU | **No CI workflow included**, no diff-awareness, no SBOM, no PR annotations. Release cadence slowed (last: Nov 2024) |
| **aminya/setup-cpp** | Widest C++ tool installer (LLVM 21, GCC 15.2), cross-platform | Setup only — installs tools, no analysis logic |
| **ModernCppStarter** | 5.3k stars, clean library/exe separation, CPM.cmake | No hardening, no fuzzing, no CodeQL, low activity (Jan 2025) |
| **filipdutescu/modern-cpp-template** | 1.9k stars | **Unmaintained since Oct 2021** |

### Google / OpenSSF

| Tool | What it does | Reusable workflow? | Coverage |
|------|-------------|-------------------|----------|
| **ClusterFuzzLite** | PR fuzzing + batch fuzzing + corpus management | No (composite Docker actions) | Fuzzing only (libFuzzer + ASan/MSan/UBSan) |
| **OSS-Fuzz** | Hosted continuous fuzzing (1,336+ projects, 13k+ vulns) | N/A (hosted service) | Open-source only, by invitation |
| **OSS-Fuzz-Gen** | LLM-generated fuzz targets (26 bugs found, incl. OpenSSL CVE-2024-9143) | N/A | Auto-generates harnesses |
| **OSV-Scanner** v2 | Dependency vulnerability scanning, container scanning | **Yes** (2 reusable workflows) | SCA only, 11+ ecosystems, SARIF output |
| **OpenSSF Scorecard** | 20-check security posture (Binary-Artifacts, Branch-Protection, Dangerous-Workflow, SAST, SBOM, Security-Policy, etc.) | No (GitHub Action) | Process checks, not code quality |
| **SLSA GitHub Generator** v1.10 | Build provenance (achieves Build L3) | **Yes** (reusable workflows) | Supply chain only. Go/Node/Maven/Container builders |
| **Allstar** | Continuous policy enforcement GitHub App | N/A (GitHub App) | Enforces Scorecard-like policies |

**Gap**: Google built the underlying tools (sanitizers, fuzzing, SLSA) but no unified CI framework. `standard` wires ASan/TSan as opt-in jobs and SLSA into auto-release, and aligns with Scorecard through SECURITY.md, Dependabot and the dangerous-workflow audit.

### Microsoft / GitHub

| Tool | What it does | C++ value |
|------|-------------|-----------|
| **CodeQL** (GHAS) | Deep semantic/dataflow SAST, C++ queries, buildless mode GA | **Best C++ security analysis** — but security only, not quality/style |
| **BinSkim** v4.4.8 | Binary hardening validation: PIE, RELRO, NX, stack-protector, FORTIFY, CFG (PE+ELF, 27 PE + 11 ELF rules) | Strong post-build validation. Similar to standard's hardening job but more rules |
| **DevSkim** v1.0.70 | Regex-based security linter (banned APIs, weak crypto) | Shallow — no AST/dataflow, catches low-hanging fruit only |
| **msvc-code-analysis-action** | MSVC /analyze + Core Guidelines | **Abandoned** (last release Aug 2021), Windows-only |
| **vcpkg SBOM** | Per-port SPDX generation + `license-report` command (July 2025) | Good for vcpkg-managed deps only |
| **microsoft/sbom-tool** | Generic SPDX 2.2/3.0 generation | **Cannot detect C++ dependencies** (no Conan/CMake/vcpkg awareness) |
| **Security DevOps Action** | Bundles BinSkim + Checkov + Trivy + Bandit + ESLint | Only BinSkim relevant for C++. No source analysis |

**Gap**: strong pieces (CodeQL, BinSkim), no orchestration layer, no reusable C++ quality workflow.

### JFrog

| Tool | What it does | C++ value |
|------|-------------|-----------|
| **Xray** | Binary SCA, SBOM (SPDX + CycloneDX), license compliance, contextual CVE analysis | Conan support. Contextual analysis reduces false positives. Requires Artifactory |
| **Artifactory** | Universal artifact repo, Conan remote, build info, binary caching | Strong for Conan-based teams |
| **Frogbot** | PR vulnerability scanning bot | **No Conan/C++ support** (open issue #355 unresolved). Significant gap given JFrog owns Conan |

### Other SCA / SAST Platforms

| Tool | Strengths vs standard | Weaknesses vs standard |
|------|----------------------|----------------------|
| **SonarQube** | Deep engine, quality dashboard, tech debt tracking, AI fix suggestions | No sanitizers, no IWYU, no infra lint, no SBOM. C++ needs paid tier ($150+/yr) |
| **Snyk** | Hash-based unmanaged C++ dep detection (no manifest needed), SAST for C/C++, container scanning | Enterprise plan required for SBOM. No formatting/build integration |
| **Sonatype Lifecycle** | CPE-based C++ vuln matching, curated CVE data beyond NVD | CPE matching produces false positives. Requires Conan manifests or SBOMs. Commercial |
| **Coverity** | Deepest C++ analysis, MISRA/CERT/AUTOSAR, <15% false positives | $50k-200k+/yr |
| **PVS-Studio** | Proprietary rules, copy-paste detection, 64-bit portability checks | $570+/yr. C++/C#/Java only |
| **CodeQL** | C++ queries, dataflow analysis, free for public repos, buildless mode | Security only. Slow. $49/committer/mo for private repos |
| **Semgrep** | Fast (10s scans), easy custom rules, 40+ languages | Pattern-based (shallow C++), no builds |

### Dependency Update Tools

| Tool | C++ support | Notes |
|------|-------------|-------|
| **Renovate** | Conan (conanfile.txt/py/lock), CPM.cmake | 90+ package managers, multi-platform, monorepo grouping, regex managers for custom patterns |
| **Dependabot** | vcpkg only (Aug 2025) | **No Conan support** (feature request closed). GitHub only. Simpler config |

## Industry Coverage Matrix

What each platform covers for C++ projects:

| Capability | standard | MegaLinter | cmake_template | JFrog | Snyk | SonarQube | CodeQL |
|---|---|---|---|---|---|---|---|
| clang-tidy (semantic) | **Yes** | No | Yes* | No | No | No | No |
| cppcheck | **Yes** | Yes | Yes* | No | No | No | No |
| clang-format | **Yes** | Yes | Yes* | No | No | No | No |
| Sanitizers (ASan/TSan) | **Yes** | No | Yes* | No | No | No | No |
| Coverage + diff-cover | **Yes** | No | Yes* | No | No | Yes | No |
| Fuzz testing | Template | No | Yes* | No | No | No | No |
| Hardening verification | **Yes** | No | Flags only | No | No | No | No |
| SBOM | **Yes** | Via trivy | No | **Yes** | **Yes** | No | No |
| Vulnerability scan | **Yes** (Grype) | Via trivy | No | **Yes** | **Yes** | No | No |
| License compliance | **Yes** | No | No | **Yes** | **Yes** | No | No |
| Secrets detection | **Yes** | **Yes** (4 tools) | No | Via Adv.Sec | No | No | No |
| Security SAST | Templates | Semgrep | CodeQL | No | **Yes** | **Yes** | **Yes** |
| Diff-aware | **Yes** | No | No | No | No | No | Incremental |
| Reusable (no copy-paste) | **Yes** | Yes | **No** | N/A | N/A | N/A | N/A |
| Auto-release + SLSA | **Yes** | No | No | No | No | No | No |
| PR annotations | **Yes** | Yes | No | Frogbot | Yes | Yes | Yes |
| Free/open-source | **Yes** | Yes | Yes | No ($$$) | No ($$$) | No ($$$) | Public repos only |

*cmake_template: copy-per-project, not reusable. Diverges after fork.

## Consumer: strong-types

`strong-types` uses `ci-fuzz.yml` end to end:
- 2 fuzz harnesses: `fuzz_safe_math.cpp` (oracle-based), `fuzz_quantity_point.cpp` (magnitude-aware)
- Dedicated `fuzz.yml` workflow: Clang 18 + libFuzzer + ASan/UBSan, 30s/harness
- CMake: `BUILD_FUZZING` + `FUZZ_USE_LIBCXX` options
- 5+ commits fixing fuzz-discovered edge cases (UB, extreme magnitudes, missing includes)
