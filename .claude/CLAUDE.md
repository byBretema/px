# px

C++ project template: CMake wrapper managing deps, opinionated defaults. Projects made from it must also work as subprojects.

Repo: `framework/` (the px CMake code), `template/` (bare project skeleton; finds px via `PX_DIR`, default `../framework`), `tests/` (ctest driver + `fixtures/`: setup projects, and `full_project_*` = projects/ + tests/ laid over a copy of the template by `tests/instantiate.cmake`). Paths below under `utils/`, `configs/` are in `framework/`; `cmake/`, `projects/` are project paths.

## Map
- `post_project()` (`framework/base.cmake`): options, toolchain, deps (the project's optional `cmake/deps.cmake`, `utils/importer.cmake`), defaults, warnings, sanitizers.
- `make_*`: `utils/scaffolding.cmake`; `setup_export` and dep installs: `utils/export.cmake`; file extensions: `utils/sources.cmake`. One target per `projects/<name>/` dir, whole tree globbed; nested `CMakeLists.txt` is an error.
- `just` only triggers (`just --list`); logic lives in CMake/presets and must work with plain `cmake --preset`.

## Common changes
- Dep: one `import_dependency()` block in `cmake/deps.cmake`. System-only libs (Qt, Boost): plain `find_package()` there, plus `setup_export(DEPS <pkg>)` if installed targets need them.
- Target: `just add_exe|add_lib <name> [SHARED|STATIC|HEADER_ONLY]`. Targets link only what they list: `make_*(<name> ... DEPS <targets>)`, compiled libs also `PRIVATE_DEPS`. Link libs as `<PROJECT_NAME>::<name>` (`myproj::core`), never by plain name. Compiled libs export only symbols marked `<NAME>_API` (generated `<name>_export.hpp`; empty for STATIC).

## Verify
- `just [preset=<preset>] test [<fixture>...]` (root justfile; = `cmake -S tests -B .build/tests -D PX_TEST_PRESET=<preset> && ctest --test-dir .build/tests -j 4`), with `debug-strict` and `debug-sanitizers` (plain parent, nested px, install, `find_package` consumer, dep version conflict, full projects with the template's presets and format check). CI runs `debug-sanitizers-strict` (Ubuntu 24.04, GCC + Clang).
- Full projects use their copy's own `.deps`: one deps dir can't hold the same dep with different patches (sources re-fetch back and forth).
- Full projects' build also compiles each public header on its own (`all_verify_interface_header_sets`).
- Read the configure log (sections `Toolchain`, `Dependencies`, `Export`).

## Gotchas
- `compile_commands.json` reaches the root via the `compile_commands` target; `--target <x>` alone doesn't refresh it.
- `.build/active_preset` (written at configure): line 1 preset, line 2 build dir. `just run` reads `<build>/exe/<name>`.
- ccache, mold, PIC, output dirs reach deps; visibility, warnings, LTO, C++ standard are own targets only.
- Changing a dep's URL/`TAG`/`PATCH` re-fetches it; local edits in `.deps/<id>-src` block the re-fetch, and the error prints how to save them as a patch.
- As a subproject: tests, install rules, `compile_commands`, `active_preset` are top-level only. Nested px projects share deps (first import wins); the last-loaded px copy's CMake functions win.
- Install bundles only the deps installed targets need (interface deps; SHARED deps for runtime), via the dep's own install rules (from its build dir: patches kept) or, for `INSTALL_HEADERS`/target-less deps, px-installed headers. `pxConfig.cmake` finds them with the built version as floor. A SHARED lib's `PRIVATE_DEPS` stay out. A dep without usable install rules fails at generate ("not in any export set"): see `import_dependency` docs.
- `just install` (`--target install`): into the preset's `installDir`, `.install/<preset>/`; plain `cmake` without presets keeps CMake's default prefix.
- `just package` (`--target package`/`package_source`): CPack TGZ (ZIP on Windows) of the install tree into `<build>/packages/`; `cpack -G <gen>` for others. Installed exes find px shared libs via relative RPATH (`$ORIGIN/../lib`).
- Linux primary (CI); non-CI code must also work on Windows and macOS. CMake floor 3.28. C++ standard: `set(PX_CXX_STANDARD <n>)` before `post_project()` (default 23); dep compiler floors: `COMPILERS` on their `import_dependency`.
