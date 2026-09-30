# Versioning Rules

All projects consuming this standard **must** follow Semantic Versioning (SemVer) with the rules below.

## Initial Version

Every new project, package, library, or component starts at **`0.0.1`**.

- `0.0.1` or `0.0.0.1` — not `1.0.0`, not `0.1.0`, not `0.0.0`
- This applies to: ROS2 packages (`package.xml`), CMake projects (`project(... VERSION ...)`), Python packages (`pyproject.toml`), Docker images, Helm charts, and any other versionable artifact

## Version Format

```
major.minor.patch[-suffix]
major.minor.patch.tweak[-suffix]
```

3 or 4 numeric segments separated by dots. Only digits, dots, hyphens and lowercase letters.

### Validation Regex

```
^[0-9]+(\.[0-9]+){2,3}(-[a-z0-9]+(-[a-z0-9]+)*)?$
```

For git tags (with `v` prefix):

```
^v[0-9]+(\.[0-9]+){2,3}(-[a-z0-9]+(-[a-z0-9]+)*)?$
```

Valid: `0.0.1`, `0.0.0.1`, `1.2.3-rc-1`, `1.2.0-proj-1234`, `0.0.3-gps-denied-nav`

Invalid: `1.0`, `1.0.0-RC1`, `1.0.0-Beta.1`, `1.0.0_feature`

### Suffixes

Two types: a release candidate, `-rc-N` (`1.2.0-rc-1`), and a feature or ticket annotation, `-name` (`1.2.0-proj-1234`). They combine: `1.0.0-rc-1-proj-567`. No `alpha`, `beta` or other pre-release names.

## `0.x.y` — Development Phase

While `MAJOR` is `0`, the project is in initial development:

- `0.MINOR.PATCH` — MINOR bumps may include breaking changes
- No stability guarantee on public API
- Acceptable for internal/unreleased projects

**Promotion to `1.0.0`** requires:
1. Public API is defined and documented
2. All CI quality gates pass
3. Explicit decision by project owner

## Bump Rules

### What triggers each bump

**PATCH bump (`x.y.Z`):**
- Bug fix
- Performance optimization (no API change)
- Internal refactoring
- Dependency update (non-breaking)
- Documentation fix
- Test addition/fix

**MINOR bump (`x.Y.0`):**
- New public function, class, or endpoint
- New optional parameter with default value
- New ROS2 topic/service/action
- New CLI flag or config option
- Deprecation of existing API (still functional)

**MAJOR bump (`X.0.0`):**
- Removed or renamed public function/class/endpoint
- Changed function signature (parameter type, order, or count)
- Changed ROS2 message/service definition
- Changed wire protocol or serialization format
- Changed config file format (existing configs stop working)
- Removed deprecated API
- Minimum dependency version raised (e.g., ROS2 Humble -> Jazzy)

### Gray areas

| Change | Bump |
|--------|------|
| Fixing a bug that people depend on (Hyrum's Law) | PATCH — bugs are not API |
| Adding a required field to a config file | MAJOR — existing configs break |
| Changing default parameter value | MINOR — behavior changes but signature doesn't |
| Renaming internal (non-public) functions | PATCH — no public API impact |
| Adding a new dependency | MINOR if optional, MAJOR if it requires consumer changes |

## Where to Set Versions

| Artifact | Location | Example |
|----------|----------|---------|
| CMake project | `project(my_lib VERSION 0.0.1)` | `CMakeLists.txt` |
| ROS2 package | `<version>0.0.1</version>` | `package.xml` |
| Python package | `version = "0.0.1"` | `pyproject.toml` |
| Docker image | Tag: `ghcr.io/org/image:0.0.1` | CI/CD pipeline |
| Git tag | `git tag v0.0.1` | Release workflow |

## Git Tags

- Tags use the `v` prefix: `v0.0.1`, `v1.2.3`
- Every release **must** have a corresponding git tag
- Tags are immutable — never delete or move a published tag
- Annotated tags preferred: `git tag -a v0.0.1 -m "Initial release"`
- [Auto-release](INTEGRATION.md#auto-release) tags every push to `main` from conventional commit prefixes

## Changelog

Every version bump should have a corresponding entry in `CHANGELOG.md` (if the project maintains one) following [Keep a Changelog](https://keepachangelog.com/) format:

```markdown
## [0.0.2] - 2026-02-19
### Fixed
- Corrected timeout handling in serial port reader
```

Categories: `Added`, `Changed`, `Deprecated`, `Removed`, `Fixed`, `Security`.

## Enforcement

### Git Tag Validation (CI)

Validate tags against the regex before a release:

```yaml
- name: Validate tag format
  if: startsWith(github.ref, 'refs/tags/v')
  run: |
    TAG="${GITHUB_REF#refs/tags/}"
    if ! echo "$TAG" | grep -qE '^v[0-9]+(\.[0-9]+){2,3}(-[a-z0-9]+(-[a-z0-9]+)*)?$'; then
      echo "::error::Invalid tag format: $TAG (expected: v0.0.1 or v0.0.0.1)"
      exit 1
    fi
```

### Source File Version Check

[`version-check.yml`](https://github.com/PavelGuzenfeld/standard/blob/main/.github/workflows/version-check.yml) validates the version in `package.xml`, `CMakeLists.txt` and `pyproject.toml` against the regex above on every PR.
