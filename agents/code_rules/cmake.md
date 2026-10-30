# CMake Rules

## Version

- `cmake_minimum_required(VERSION 3.28)`
- Preset version: `8`

## Naming

- Targets: `snake_case` (`core`, `test_core`, `test_patch`)
- Lib real targets: `<PROJECT_NAME>_<name>` (`px_core`), `EXPORT_NAME <name>`; link via the `<PROJECT_NAME>::<name>` alias. Exes: plain at top level, prefixed when nested. Tests: plain (top level only)
- Test targets: `test_` prefix
- Dep aliases: `namespace::target` (e.g., `fmt::fmt`)
- Internal aliases: `namespace_target` (e.g., `fmt_fmt`)

## Variables

- Internal: double-underscore prefix (`__base_dir`, `__fetched_*`)
- Options: UPPER_SNAKE with intent prefix
  - `USE_*` — enable tooling (ccache, mold)
  - `ENABLE_*` — enable sanitizers (asan, ubsan)
  - `FORCE_*` — force behavior (warnings as errors)
- Local: `snake_case` or `_` prefix

## Functions

- Prefer `function()`; `macro()` only when the caller's scope must be modified (`pre_project`, `post_project`, `setup_testing`, logger)
- `snake_case`: `setup_warnings`, `setup_sanitizers`, `import_dependency`
- Internal: double-underscore prefix: `__glob_sources`, `__add_dependency`
- Output vars: `out_var` pattern with `PARENT_SCOPE`

## Scaffolding DSL

| Function | Purpose |
|---|---|
| `make_exe(name)` | Executable, auto-glob, link deps, warnings/sanitizers |
| `make_lib(name type)` | Shared/static lib, same pattern |
| `make_hlib(name)` | Header-only interface library (alias of `make_lib_header_only`) |
| `make_test(name)` | Like `make_exe` + `add_test()`, not exported |

- Library headers: recursive glob into a `FILE_SET HEADERS` (dir is the include root); installed to `include/<ns>/<target>/`
- Libraries link deps as `$<BUILD_INTERFACE:all_dependencies>`; deps never appear in the export
- Sources: recursive glob of `*.cpp *.cc *.c *.cxx` + headers over the whole target dir (no hand-listed sources); nested `CMakeLists.txt` is a configure error

## Modules

- `include_guard(DIRECTORY)` in all cmake/ modules
- `GNUInstallDirs` for portable install paths

## Dependencies

- All deps through `import_dependency()` (FetchContent wrapper)
- Installed libs only (Qt, Boost, Vulkan...): plain `find_package()` in `cmake/deps.cmake`, linked into `all_dependencies`; no system fallback for fetched deps
- Sources: importer does a shallow `git fetch <TAG>` into `DEPS_DIR/<id>-src`; `<id>.stamp` (`URL@TAG` + PATCH hash) triggers re-fetch on any change
- Patches: `cmake/patches/<dep>.patch` (git diff, preferred) or `<dep>.cmake` (script); format and workflow in `cmake/patches/README.md`
- `FetchContent_Declare(SOURCE_DIR ... SYSTEM)` + `FetchContent_MakeAvailable` for `add_subdirectory` only
- Deps dir: `DEPS_DIR` (env or cache), default `${CMAKE_SOURCE_DIR}/.deps`; sources only, dep build trees in `<build>/_deps/`
- Toolchain settings (ccache, mold, PIC, output dirs) are set before deps so they apply to them
- `all_dependencies` aggregate INTERFACE target

## Defaults

| Setting | Value |
|---|---|
| C++ standard | `cxx_std_23` compile feature (`PUBLIC` on libs, so installed consumers inherit it); `CMAKE_CXX_STANDARD` can only raise it |
| Symbol visibility | `hidden` |
| PIC | `ON` |
| LTO | `ON` for Release/RelWithDebInfo, if `check_ipo_supported()` |
| Build output | `.build/<debug\|profile\|release>[_san]` (presets) |
| Deps dir | `.deps/` |
| Generator | Ninja (presets) |
| Default build type | `Release` |
