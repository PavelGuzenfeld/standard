# Install test

[`install-test.yml`](https://github.com/PavelGuzenfeld/standard/blob/main/.github/workflows/install-test.yml): Install the package and check `find_package` from a consumer. Pin to a release SHA, as [Versioning](../VERSIONING.md) says.

| Input | Type | Default | Description |
|-------|------|---------|-------------|
| `cmake_version` | string | `''` | CMake version to install (empty = use runner default) |
| `build_type` | string | `'Release'` | CMAKE_BUILD_TYPE for the library build |
| `cmake_args` | string | `''` | Extra CMake configure args for the library (e.g., -DBUILD_TESTING=OFF) |
| `install_prefix` | string | `'/tmp/install'` | CMAKE_INSTALL_PREFIX for the library |
| `consumer_dir` | string | `''` | Path to a consumer CMake project (must have CMakeLists.txt with find_package). Empty = auto-generate a minimal consumer. |
| `package_name` | string | `''` | Package name for find_package() in auto-generated consumer (required if consumer_dir is empty) |
| `target_name` | string | `''` | CMake target to link (e.g., MyLib::MyLib). Defaults to package_name::package_name |
| `header_check` | string | `''` | Header to #include in the consumer test (e.g., mylib/mylib.hpp). Empty = skip header check. |
| `docker_image` | string | `''` | Docker image to run inside (empty = run natively on runner) |
| `source_mount` | string | `'/workspace/src'` | Mount point for source inside Docker container |
| `runner` | string | `'"ubuntu-latest"'` | Runner labels as JSON |
