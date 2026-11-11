# Changelog

px follows [semantic versioning](https://semver.org). While in 0.x, a minor
release may break projects, so `find_package(px 0.1)` accepts only `0.1.x`.

## Unreleased

- **Lock file**: configure writes `cmake/deps.lock`, the commit each dep's
  URL and `TAG` resolved to, and fetches that commit while they match
  (`PX_DEPS_LOCK`). Deps are re-fetched once, as their stamps now also hold
  the commit.
- **Fix**: the "save your local changes as a patch" hint pointed into px's
  own dir; it now names the project's `cmake/patches/<ns>.patch`.
- **Sanitizers**: support is probed at configure, so a toolchain without the
  sanitizer runtimes (MinGW GCC, for one) fails there with a clear message.
- **mold**: used for ELF targets only; skipped for Windows (MinGW included)
  and macOS.

## 0.1.0

First release.

- **Layout**: `framework/` (px itself), `template/` (the skeleton a project
  starts from), `tests/` (fixtures CI builds px in).
- **Loading px**: the template's `cmake/px.cmake` uses `PX_DIR`, else an
  installed px, else fetches `PX_GIT_TAG` (default `v0.1.0`) once into the
  deps dir. A px project nested in another reuses the parent's px and checks
  its version.
- **Targets**: one per `projects/<name>/` dir, sources globbed.
  `make_exe`, `make_lib(SHARED|STATIC|HEADER_ONLY)`, `make_test`, each linking
  only its own `DEPS` (libs also `PRIVATE_DEPS`). Libs are
  `<project>::<name>`; compiled libs export what `<NAME>_API` marks.
- **Dependencies**: `import_dependency()` in `cmake/deps.cmake`: shallow git
  fetch of a tag or commit, optional patch, `OPTIONS`, `DEFINES`, per-dep
  build type and compiler floors. Sources are shared across build dirs and
  re-fetched only when URL, tag or patch change; local edits block a re-fetch.
- **Defaults**: C++23 (`PX_CXX_STANDARD`), strict warnings for own targets
  only (`PX_EXTRA_WARNINGS`), hidden visibility, PIC, LTO in Release and
  RelWithDebInfo (not for STATIC libs), ccache, mold,
  `compile_commands.json` at the project root.
- **Presets**: `debug`, `profile`, `release`, each with `-asan`, `-ubsan`,
  `-sanitizers` and `-strict` (warnings as errors) variants.
- **Install and package**: `setup_export()` installs targets with a
  `find_package` config, plus only the deps installed targets need, through
  the deps' own install rules. CPack archives; relocatable RPATH.
- **As a subproject**: under any CMake project or another px project, with
  shared deps and prefixed exe names.
- **Tooling**: `just` recipes over plain CMake (build, test, run, install,
  package, format, add_exe, add_lib); clang-format with a pinned version.
- **Generators**: Ninja (presets), Ninja Multi-Config and Unix Makefiles.
