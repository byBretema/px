# px

C++ project template: CMake wrapper managing deps, opinionated defaults. Projects made from it must also work as subprojects.

Repo: `new.cmake` (`cmake -D NAME=<n> -P new.cmake`: template of `__release_tag`, which CI's release job sets in the published copy, else the latest `v*` tag; `myproj` renamed; `git init` unless inside a repo; always the cwd, NAME default its name; non-empty needs `-D FORCE=ON`. `new.sh` / `new.ps1` wrap it for `curl | sh` / `irm | iex`: tool checks, the non-empty prompt (`/dev/tty`; `Read-Host`), args to cmake; keep them in step; their new.cmake URL is pinned by the release job too), `framework/` (the px CMake code), `template/` (bare project skeleton; `cmake/px.cmake` loads px from `PX_DIR`, else installed, else git-fetches `PX_GIT_TAG` into `<deps>/px-<tag>`; in-repo copies need `PX_DIR=<repo>/framework`), `tests/` (ctest driver + `fixtures/`: setup projects, and `template_example_project` = projects/ + tests/ laid over a copy of the template by `tests/instantiate.cmake`). Paths below under `utils/`, `configs/` are in `framework/`; `cmake/`, `projects/` are project paths.

## Map
- `post_project()` (`framework/base.cmake`): options, toolchain, deps (the project's optional `cmake/deps.cmake`, `utils/importer.cmake`), defaults, warnings, sanitizers.
- `make_*`: `utils/scaffolding.cmake`; `setup_export` and dep installs: `utils/export.cmake`; file extensions: `utils/sources.cmake`. One target per `projects/<name>/` dir, whole tree globbed; nested `CMakeLists.txt` is an error.
- `just` only triggers (`just --list`); logic lives in CMake/presets and must work with plain `cmake --preset`.

## Common changes
- Dep: one `import_dependency()` block in `cmake/deps.cmake`. System-only libs (Qt, Boost): plain `find_package()` there, plus `setup_export(DEPS <pkg>)` if installed targets need them.
- Target: `just add_exe|add_lib <name> [SHARED|STATIC|HEADER_ONLY]`. Targets link only what they list: `make_*(<name> ... DEPS <targets>)`, compiled libs also `PRIVATE_DEPS`. Link libs as `<PROJECT_NAME>::<name>` (`myproj::core`), never by plain name. Compiled libs export only symbols marked `<NAME>_API` (generated `<name>_export.hpp`; empty for STATIC).

## Verify
- `just [preset=<preset>] [asan=true ...] test [<fixture>...]` (root justfile; = `cmake -S tests -B .build/tests -D PX_TEST_PRESET=<preset> -D "PX_TEST_CHECKS=-DPX_FORCE_ERRORS=ON;..." && ctest --test-dir .build/tests -j 4`), with defaults (strict) and `asan=true ubsan=true` (4 builds, named by intent, `docs/developing-px.md`: `libs_release_lto_asan` + LSan leak, `libs_multi_config`, each installed and `find_package`d by `consume_*`; `nested_px_tsan_lock` (px parent, TSan race, `deps.lock` pin); `template_example_project` via the template's presets + format check; `new_project_*`: `new.cmake` from a local git repo of the checkout (`tests/px_repo.cmake`, framework/ + template/, tagged `v<PX_VERSION>`), fetch + build. Configure-only: `dep_version_conflict`, `px_version_rejected_*`, `tsan_with_asan_refused`, `msan_*` (MSan build on Clang, refused otherwise)). CI runs `debug` + strict + ASan + UBSan (Ubuntu 24.04, GCC + Clang).
- `template_example_project` uses its copy's own `.deps`: one deps dir can't hold the same dep with different patches (sources re-fetch back and forth).
- Its build also compiles each public header on its own (`all_verify_interface_header_sets`).
- Read the configure log (sections `Toolchain`, `Dependencies`, `Export`).

## Gotchas
- `compile_commands.json` reaches the root via the `compile_commands` target; `--target <x>` alone doesn't refresh it.
- Presets are build types only (`debug`, `profile`, `release`); checks are cache options (`PX_ENABLE_*SAN`, `PX_FORCE_ERRORS`), sticky in the build dir, set by `just strict=true asan=true ...` (template justfile passes `-D` and reconfigures); `configs/sanitizers.cmake` rejects bad combinations.
- `.build/active_preset` (written at configure): line 1 preset, line 2 build dir, line 3 px dir (`just` format/add_* read it). Preset configures only. `just run` reads `<build>/exe/<name>`.
- ccache, mold, PIC, output dirs reach deps; visibility, warnings, LTO, C++ standard are own targets only.
- `cmake/deps.lock` (`PX_DEPS_LOCK`, empty: off; tests pass it empty, `nested_px_tsan_lock` and the `template_example_project` copy use it): URL@TAG -> commit, fetched instead of TAG while it matches; written (deferred, only if changed) by the top-level px project, read by the outermost; `.deps/<id>.stamp` line 2 is the fetched commit.
- Changing a dep's URL/`TAG`/`PATCH` re-fetches it; local edits in `.deps/<id>-src` block the re-fetch, and the error prints how to save them as a patch.
- As a subproject: tests, install rules, `compile_commands`, `active_preset` are top-level only. Nested px projects share deps (first import wins) and px itself: the cached `px_DIR` from the parent's `find_package(px)` wins over the child's `PATHS`, and the child's version request is checked against it.
- px version: `framework/version.cmake` (`PX_VERSION`), equal to the template's `cmake/px.cmake` `__px_version` (tests configure checks; `just publish_tag X.Y.Z` sets both, commits, tags, pushes; release steps: `docs/developing-px.md`; docs never name the version), checked by `pxConfigVersion.cmake`: same major and >= requested; in 0.x also the same minor. Bump the minor for breaking changes while 0.x.
- Customization never edits `framework/`: `docs/configuration.md` "Customizing" (options, vars before/after `post_project()`, `PX_EXTRA_WARNINGS`, `target_*` after `make_*`).
- Install bundles only the deps installed targets need (interface deps; SHARED deps for runtime), via the dep's own install rules (from its build dir: patches kept) or, for `INSTALL_HEADERS`/target-less deps, px-installed headers. `pxConfig.cmake` finds them with the built version as floor. A SHARED lib's `PRIVATE_DEPS` stay out. A dep without usable install rules fails at generate ("not in any export set"): see `import_dependency` docs.
- `just install` (`--target install`): into the preset's `installDir`, `.install/<preset>/`; plain `cmake` without presets keeps CMake's default prefix.
- `just package` (`--target package`/`package_source`): CPack TGZ (ZIP on Windows) of the install tree into `<build>/packages/`; `cpack -G <gen>` for others. Installed exes find px shared libs via relative RPATH (`$ORIGIN/../lib`).
- Linux primary (CI); non-CI code must also work on Windows and macOS. CMake floor 3.28. C++ standard: `set(PX_CXX_STANDARD <n>)` before `post_project()` (default 23); dep compiler floors: `COMPILERS` on their `import_dependency`.
