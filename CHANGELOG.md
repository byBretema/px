# Changelog

px follows [semantic versioning](https://semver.org). While in 0.x, a minor
release may break projects, so `find_package(px 0.1)` accepts only `0.1.x`.

## 0.1.5

- **Hardening**, on by default for own targets: stack protector, stack
  clash protection, CET / branch protection, relro/now, `_FORTIFY_SOURCE=3`
  in optimized builds, and standard library assertions in Debug. A memory
  bug now aborts with a message instead of corrupting memory. Off with
  `just hardening=false` (`PX_ENABLE_HARDENING`); STL assertions in every
  config with `just stl_checks=true` (`PX_ENABLE_STL_ASSERTIONS`).
- **Sanitizers on Windows**: clang-cl gets UBSan, and its sanitizer runtime
  is linked (CMake links clang-cl without the driver, so ASan builds failed
  to link). Clang ASan builds use the release CRT for the whole tree, since
  it rejects the debug one. ASan turns incremental linking off and copies
  its runtime DLL next to each exe.
- **Fix**: on Windows, a Debug project failed to link compiled C++ deps
  (LNK2038): deps build as Release with the release CRT. They now keep the
  project's CRT (debug CRT in Debug), still optimized. Deps below
  `cmake_minimum_required(3.15)` get it too.

## 0.1.4

- **Checks instead of preset variants**: presets are now only `debug`,
  `profile` and `release`. Sanitizers and warnings as errors are options on
  top of any of them: `just asan=true ubsan=true strict=true build`, or
  `-D PX_ENABLE_ASAN=ON` etc. with plain CMake. They stay in the build dir
  until set again, and the configure log shows them. The `*-asan`,
  `*-sanitizers`, `*-strict`, ... presets are gone, and every preset builds
  into `.build/<preset>/`.
- **Sanitizers**: TSan, MSan (Clang) and LSan (`PX_ENABLE_TSAN`,
  `PX_ENABLE_MSAN`, `PX_ENABLE_LSAN`; `just tsan=true` ...). Combinations
  the compilers reject fail at configure.
- **Renamed** `PX_FORCE_ERROR` to `PX_FORCE_ERRORS`; the old name is
  ignored.
- **Presets** have a display name and a description for IDEs.
- The template's `.gitignore` ignores `CMakeUserPresets.json`.
- **px's tests**: 4 builds per compiler instead of about 14, each
  combining several checks and named after them (`libs_release_lto_asan`,
  `libs_multi_config`, `nested_px_tsan_lock`, `template_example_project`).
  The new-project test now also builds. Dropped: the plain CMake parent and
  the Debug install. CI lowers ASLR entropy so TSan can start.

## 0.1.3

- **Fix**: `just` (the project list) failed in a project without tests.
- **Fix**: `just test` / `ctest --preset` failed in a project without tests;
  the test presets no longer set `noTestsAction` to `error`.

## 0.1.2

- **New project**: `curl -fsSL https://github.com/byBretema/px/releases/latest/download/new.sh | sh`
  (or `irm …/new.ps1 | iex` on Windows) turns the current dir into a git repo
  made from the latest release's template, named after the dir. They check
  for CMake and git, ask before using a dir that isn't empty, and run
  `new.cmake` (`NAME`, `FORCE`, `PX_GIT_TAG`).
- **Releases**: a green `v*` tag becomes a GitHub Release, with its
  CHANGELOG section and `new.cmake`, `new.sh`, `new.ps1` pinned to it.

## 0.1.1

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
