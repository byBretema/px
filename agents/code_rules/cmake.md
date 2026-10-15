# CMake Rules

## Version

- `cmake_minimum_required(VERSION 3.28)`
- Preset version: `8`

## Naming

- Targets: `snake_case` (`core`, `test_core`, `test_malloc`)
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

- Prefer `function()`; `macro()` only when the caller's scope must be modified (`pre_project`, `post_project`, logger)
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

- Sources: non-recursive glob of `*.cpp *.cc *.c *.cxx` + headers in the target dir

## Modules

- `include_guard(DIRECTORY)` in all cmake/ modules
- `GNUInstallDirs` for portable install paths

## Dependencies

- All deps through `import_dependency()` (FetchContent wrapper)
- `FetchContent_Declare` + `FetchContent_MakeAvailable`
- `GIT_SHALLOW TRUE` + `SYSTEM TRUE`
- Deps dir: `DEPS_DIR` (env or cache), default `${CMAKE_BINARY_DIR}/.deps`; `just` exports `<root>/.deps`
- `all_dependencies` aggregate INTERFACE target

## Defaults

| Setting | Value |
|---|---|
| Symbol visibility | `hidden` |
| PIC | `ON` |
| LTO | `ON` for Release/RelWithDebInfo, if `check_ipo_supported()` |
| Build output | `.build/` (justfile); presets alone use `build/<preset>` |
| Deps dir | `.deps/` |
| Generator | Ninja (justfile `-G`; presets set none) |
| Default build type | `Release` |
