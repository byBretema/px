# PX

> A C++ project start point: CMake wrapper to manage deps and opinionated sane defaults.

## Layout

- `CMakeLists.txt`: entry point. `pre_project()` / `project()` / `post_project()`, then `projects/`, `tests/`, export.
- `cmake/base.cmake`: `post_project()` include order: options, toolchain (ccache, mold, `global.cmake`), deps, defaults, warnings, sanitizers.
- `cmake/deps.cmake`: every external dependency, one `import_dependency()` call each.
- `cmake/utils/importer.cmake`: `import_dependency()` (FetchContent wrapper) and the `all_dependencies` target.
- `cmake/utils/scaffolding.cmake`: `make_exe`, `make_lib`, `make_hlib`, `make_test`, `setup_testing`, `setup_export`.
- `cmake/configs/*.cmake`: one concern per file (options, warnings, sanitizers, ccache, mold, mimalloc, LTO/defaults).
- `projects/<name>/`: one target per dir; every source in the dir tree (subdirs included) is compiled. Code that must not be compiled lives outside `projects/`; nested `CMakeLists.txt` is an error.
- `tests/<name>/`: test executables (`make_test`), registered with CTest.
- `vendor/`: drop-in third-party headers, on the include path of every target.

## Commands

All via `just` (bash). Build dirs `.build/<group>/`, deps sources `.deps/`, ccache `.cache/` (ccache `cache_dir` passed by CMake, no env needed).

- `just build [targets...]`: build the active preset (last used, default `debug`). Configures only on first use, preset switch or `config_flags=...`; otherwise `cmake --build` re-runs CMake itself when CMake files or globbed dirs change.
- `just config`: force a configure (e.g. after editing `CMakePresets.json`, which ninja does not track).
- `just preset=profile-strict build`: switch preset; later `just build/run/test` reuse it.
- Presets: `{debug,profile,release}[-asan|-ubsan|-sanitizers][-strict]` (`cmake --list-presets`).
- `just test [tests...]`: build + run CTest.
- `just run <target> [args]`: build + run an executable.
- `just add_exe <name>` / `just add_lib <name> [SHARED|STATIC]`: scaffold under `projects/`.
- `just clean [build|deps|all]`.

Without `just`: `cmake --preset debug && cmake --build --preset debug && ctest --preset debug` (every configure preset has matching build/test presets; test presets fail when no tests are found).

## Common changes

- New dependency: add an `import_dependency(ns::target GITHUB org/repo TAG <tag> SUBDIR <include-dir> [OPTIONS K=V...] [DEFINES MACRO...])` block to `cmake/deps.cmake`. It is linked into every target through `all_dependencies`.
- New target: create `projects/<name>/CMakeLists.txt` with one `make_*` call, then `add_subdirectory(<name>)` in `projects/CMakeLists.txt`.
- New option: `cmake/configs/options.cmake`, following the `USE_*` / `ENABLE_*` / `FORCE_*` prefixes.

## Verify

- Configure + build + test with `debug-strict` (warnings as errors) and `debug-sanitizers` after CMake or C++ changes.
- CI (`.github/workflows/ci.yml`) runs `debug-sanitizers-strict` on Ubuntu 24.04 with GCC and Clang, using plain CMake presets. Skipped for doc-only changes (`*.md`, `agents/`, `LICENSE`, `.gitignore`).
- Read the configure log: the wrapper prints a section per stage (`Toolchain`, `Dependencies`, `Export`).

## Gotchas

- Known bugs and backlog: `agents/tasks/improvements.md`. Read it before touching `cmake/`.
- `compile_commands.json` reaches the source root via the `compile_commands` target (part of `ALL`). `cmake --build --target <x>` alone does not refresh it.
- Build dir groups: `.build/<debug|profile|release>[_san]`. Presets in the same group (e.g. `debug`/`debug-strict`, `debug-asan`/`debug-ubsan`) share a dir and rebuild when switched.
- `.build/active_preset` (written by CMake at configure): line 1 preset (just's default), line 2 build dir (used by `just run`). `just build`/`test` call `cmake --build --preset` / `ctest --preset`.
- ccache, mold, PIC, output dirs apply to deps too; visibility, warnings, LTO, C++ standard apply to own targets only.
- Changing a dep's URL, `TAG` or `PATCH` file re-fetches that dep on next configure; no `just clean deps` needed. A re-fetch refuses to wipe local edits in `.deps/<id>-src`; the error prints the commands to capture them as `cmake/patches/<ns>.patch` (see `cmake/patches/README.md`).
- Installed package: px headers/libs only (no deps), headers at `include/<ns>/<target>/`. Installed STATIC libs that use compiled deps can't be linked by consumers (deps are not installed).

## Code rules

- `agents/code_rules/cpp.md`
- `agents/code_rules/cmake.md`

## Tasks

- `agents/tasks/improvements.md`
