# px

C++ project template: CMake wrapper managing deps, opinionated defaults. Projects made from it must also work as subprojects.

## Map
- `post_project()` (`cmake/base.cmake`): options, toolchain, deps (`cmake/deps.cmake`, `utils/importer.cmake`), defaults, warnings, sanitizers.
- `make_*` / `setup_export`: `cmake/utils/scaffolding.cmake`. One target per `projects/<name>/` dir, whole tree globbed; nested `CMakeLists.txt` is an error.
- `just` only triggers (`just --list`); logic lives in CMake/presets and must work with plain `cmake --preset`.

## Common changes
- Dep: one `import_dependency()` block in `cmake/deps.cmake`. System-only libs (Qt, Boost): plain `find_package()` there, linked into `all_dependencies`.
- Target: `just add_exe|add_lib <name>`. Link libs as `<PROJECT_NAME>::<name>` (`px::core`), never by plain name.

## Verify
- `debug-strict` and `debug-sanitizers`: configure, build, test. CI runs `debug-sanitizers-strict` (Ubuntu 24.04, GCC + Clang).
- Read the configure log (sections `Toolchain`, `Dependencies`, `Export`).

## Gotchas
- `compile_commands.json` reaches the root via the `compile_commands` target; `--target <x>` alone doesn't refresh it.
- `.build/active_preset` (written at configure): line 1 preset, line 2 build dir. `just run` reads `<build>/exe/<name>`.
- ccache, mold, PIC, output dirs reach deps; visibility, warnings, LTO, C++ standard are own targets only.
- Changing a dep's URL/`TAG`/`PATCH` re-fetches it; local edits in `.deps/<id>-src` block the re-fetch, and the error prints how to save them as a patch.
- As a subproject: tests, install rules, `compile_commands`, `active_preset` are top-level only. Nested px projects share deps (first import wins); the last-loaded px copy's CMake functions win.
- Installed package has no deps: installed STATIC libs using compiled deps can't be linked by consumers.
- Linux primary (CI); non-CI code must also work on Windows and macOS. CMake floor 3.28.
