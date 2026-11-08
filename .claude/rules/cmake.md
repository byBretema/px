---
description: CMake conventions and design decisions for px.
paths:
  - "**/CMakeLists.txt"
  - "**/*.cmake"
  - "CMakePresets.json"
---

## Style
- `cmake_minimum_required(VERSION 3.28)`, presets version `8`. Newer features (`CMAKE_LINKER_TYPE`, `CMAKE_MSVC_RUNTIME_CHECKS`) get minimal workarounds.
- `function()` by default; `macro()` only when the caller's scope must change (`pre_project`, `post_project`, `setup_testing`, logger).
- Internal functions/vars: `__` prefix (`__glob_sources`, `__base_dir`). Locals: `snake_case`. Out vars via `PARENT_SCOPE`.
- Options: `USE_*` tooling, `ENABLE_*` sanitizers, `FORCE_*` behaviour.
- `include_guard(DIRECTORY)` in every `cmake/` module; `GNUInstallDirs` for install paths.

## Targets
- `snake_case`; tests `test_` prefix, plain names, top level only.
- Libs: real target `<PROJECT_NAME>_<name>`, `EXPORT_NAME <name>`, alias `<PROJECT_NAME>::<name>`. Exes: plain at top level, prefixed when nested.
- Sources and headers globbed over the whole target dir (extensions only in `utils/sources.cmake`); never listed by hand. All `make_*` go through `__make_target`. Lib headers: `FILE_SET HEADERS` with the dir as include root, installed to `include/<ns>/<name>/`.
- Standard: `PX_CXX_STANDARD` (project, default 23) as a `cxx_std_<n>` compile feature (`PUBLIC` on libs); `CMAKE_CXX_STANDARD` can only raise it. Dep version floors: `import_dependency(... COMPILERS GNU=13 ...)`, not central. Visibility hidden, PIC on, LTO on Release/RelWithDebInfo when supported.
- Warning flags `PRIVATE`, never leaked to consumers.
- Deps per target (`DEPS`, `PRIVATE_DEPS`), through the px wrapper `__px_dep_<ns>_<target>` (SUBDIR include, DEFINES; exportable). No catch-all dep target.
- SHARED libs hide static deps' symbols: `--exclude-libs,ALL`; macOS `-load_hidden` per archive (deferred, walks the link closure).

## Dependencies
- Only through `import_dependency()`; `SUBDIR` required, no auto-detection.
- Importer owns sources: shallow `git fetch <TAG>` into `DEPS_DIR/<id>-src`, keyed by `<id>.stamp` (URL@TAG + PATCH hash). Sources shared across build dirs; build trees (`<build>/_deps/`) never shared.
- `FetchContent_Declare(SOURCE_DIR ... SYSTEM EXCLUDE_FROM_ALL)` + `MakeAvailable` only for `add_subdirectory`. `EXCLUDE_FROM_ALL` keeps dep install rules out; `setup_export` adds `install(SCRIPT <dep build>/cmake_install.cmake)` only for deps installed targets need.
- Dep install options defaulting OFF as a subproject go ON in `OPTIONS` (harmless: only run when needed). No usable install rules: `INSTALL_HEADERS` (header-only) or keep it out of installed interfaces.
- `OPTIONS` use `CACHE FORCE`: the only way to override dep cache entries before `add_subdirectory`.
- Dep build type: plain `set(CMAKE_BUILD_TYPE)` in function scope, not `CACHE FORCE` (reconfigure loops).
- Toolchain settings (ccache, mold, PIC, output dirs) set before deps so they reach them.
- Patches: `cmake/patches/<ns>.patch` (git diff, preferred) or `<ns>.cmake` script; see `cmake/patches/README.md`.
- No `CMAKE_DEBUG_POSTFIX`: conflicts with per-dep build types.
- No `find_package` fallback for fetched deps (dropped: bypasses patches, options, sanitizers; machine-dependent versions).

## Cross-directory state
- Normal vars are directory-scoped: use them for per-project state (`__base_dir`) so nested px projects keep their own.
- Global properties for cross-subdir lists: `__px_export_<project>`, `__px_fetched_<fetch_id>` (stamp), `__px_dep_of_<real target>`. Per-dep install data: `PX_DEP_*` properties on the wrapper.
- Target names and functions are global: guard shared targets (`if(TARGET __px_dep_...) return()`).
