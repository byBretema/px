# PX

> A C++ project start point: CMake wrapper to manage deps and opinionated sane defaults.

## Layout

- `CMakeLists.txt`: entry point. `pre_project()` / `project()` / `post_project()`, then `projects/`, `tests/`, export.
- `cmake/base.cmake`: `post_project()` include order (options, deps, defaults, cache, linker, warnings, sanitizers).
- `cmake/deps.cmake`: every external dependency, one `import_dependency()` call each.
- `cmake/utils/importer.cmake`: `import_dependency()` (FetchContent wrapper) and the `all_dependencies` target.
- `cmake/utils/scaffolding.cmake`: `make_exe`, `make_lib`, `make_hlib`, `make_test`, `setup_testing`, `setup_export`.
- `cmake/configs/*.cmake`: one concern per file (options, warnings, sanitizers, ccache, mold, mimalloc, LTO/defaults).
- `projects/<name>/`: one target per dir; sources are globbed non-recursively from the dir itself.
- `tests/<name>/`: test executables (`make_test`), registered with CTest.
- `vendor/`: drop-in third-party headers, on the include path of every target.

## Commands

All via `just` (bash). Build dirs `.build/<group>/`, deps sources `.deps/`, ccache `.cache/`.

- `just build [targets...]`: configure + build the active preset (last used, default `debug`).
- `just preset=profile-strict build`: switch preset; later `just build/run/test` reuse it.
- Presets: `{debug,profile,release}[-asan|-ubsan|-sanitizers][-strict]` (`cmake --list-presets`).
- `just test [tests...]`: build + run CTest.
- `just run <target> [args]`: build + run an executable.
- `just add_exe <name>` / `just add_lib <name> [SHARED|STATIC]`: scaffold under `projects/`.
- `just clean [build|deps|all]`.

Without `just`: `cmake --preset debug && cmake --build .build/debug && ctest --test-dir .build/debug`.

## Common changes

- New dependency: add an `import_dependency(ns::target GITHUB org/repo TAG <tag> SUBDIR <include-dir> [OPTIONS K=V...])` block to `cmake/deps.cmake`. It is linked into every target through `all_dependencies`.
- New target: create `projects/<name>/CMakeLists.txt` with one `make_*` call, then `add_subdirectory(<name>)` in `projects/CMakeLists.txt`.
- New option: `cmake/configs/options.cmake`, following the `USE_*` / `ENABLE_*` / `FORCE_*` prefixes.

## Verify

- Configure + build + test with `debug-strict` (warnings as errors) and `debug-sanitizers` after CMake or C++ changes.
- Read the configure log: the wrapper prints a section per stage (`Fulfilling dependencies`, `Setup`, `Export`).

## Gotchas

- Known bugs and backlog: `agents/tasks/improvements.md`. Read it before touching `cmake/`; C3 (`make_lib` breaks export) affects basic use.
- `compile_commands.json` reaches the source root via the `compile_commands` target (part of `ALL`). `cmake --build --target <x>` alone does not refresh it.
- Build dir groups: `.build/<debug|profile|release>[_san]`. Presets in the same group (e.g. `debug`/`debug-strict`, `debug-asan`/`debug-ubsan`) share a dir and rebuild when switched.
- `.build/active_preset` (written by CMake at configure): line 1 preset, line 2 build dir.
- Global defaults (visibility, warnings, LTO) apply to own targets only, not deps.
- glaze forces `cxx_std_23` on every target through `all_dependencies`.

## Code rules

- `agents/code_rules/cpp.md`
- `agents/code_rules/cmake.md`

## Tasks

- `agents/tasks/improvements.md`
