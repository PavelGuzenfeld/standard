# Version sync

[`version-sync.yml`](https://github.com/PavelGuzenfeld/standard/blob/main/.github/workflows/version-sync.yml): Sync opt-in version files to a release tag; this repo enables only pyproject.toml. Pin to a release SHA, as [Versioning](../VERSIONING.md) says.

| Input | Type | Default | Description |
|-------|------|---------|-------------|
| `tag` | string | required | Release tag (e.g. v1.2.3) |
| `default_branch` | string | `'main'` | Branch to checkout and push to |
| `enable_cmake` | boolean | `false` | Update project(... VERSION x.y.z) in CMakeLists.txt |
| `cmake_path` | string | `'CMakeLists.txt'` | Path to CMakeLists.txt |
| `enable_readme_fetchcontent` | boolean | `false` | Update GIT_TAG vx.y.z in README.md |
| `readme_path` | string | `'README.md'` | Path to README file |
| `enable_pyproject` | boolean | `false` | Update version = "x.y.z" in pyproject.toml |
| `pyproject_path` | string | `'pyproject.toml'` | Path to pyproject.toml |
| `enable_package_xml` | boolean | `false` | Update &lt;version&gt;x.y.z&lt;/version&gt; in package.xml |
| `package_xml_path` | string | `'package.xml'` | Path to package.xml |
| `enable_package_json` | boolean | `false` | Update "version": "x.y.z" in package.json |
| `package_json_path` | string | `'package.json'` | Path to package.json |
