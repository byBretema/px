# Improvements

> Single backlog for px. Supersedes `rework.md` (audit items B1–B15, all closed; see git history).

Status legend: **Open**, **Verified** (reproduced on CMake 4.4.4 / GCC / Ninja, 2026-10-15), **Inspected** (from code reading only).

## Correctness — High

Each of these breaks a common workflow today.

- [x] **C1 Fresh configure fails** (Fixed 2026-10-15: `compile_commands` build target copies it, Ninja/Makefiles) — `cmake/configs/compile_commands.cmake:10`
  - `file(COPY_FILE)` runs at configure time, but `compile_commands.json` is only written at generate time. A fresh build dir always hits `file COPY_FILE failed to copy ... No such file or directory`, generation never runs, so the file never appears. Every clean clone is broken unless `-DUSE_COMPILE_COMMANDS=OFF`.
  - Even when the file exists, the copy is one configure stale.
  - Fix: drop the copy; point clangd at the build dir (`.clangd` `CompilationDatabase: .build`), or copy after generate in `just config` (`cmake -E copy_if_different`). `cmake_language(DEFER)` still runs before generate, so it does not help.
- [x] **C2 `just add_exe` / `add_lib` write unparseable CMake** (Fixed 2026-10-15) — `justfile:143,154`
  - `echo "add_subdirectory(x)\n"` writes a literal `\n`; next configure fails with `Parse error. Expected a command name, got unquoted argument with text "\n"`.
  - Fix: `printf 'add_subdirectory(%s)\n'`.
- [ ] **C3 `make_lib` + `setup_export` fails at generate** (Verified) — `cmake/utils/scaffolding.cmake:54`
  - `make_lib` links `all_dependencies` `PUBLIC`; it is in no export set, so generate fails: `install(EXPORT "px-targets" ...) includes target "bar" which requires target "all_dependencies" that is not in any export set`.
  - Fix: link deps `PRIVATE` (or `$<BUILD_INTERFACE:all_dependencies>`), and let libs declare their own public deps.
- [ ] **C4 Bumping a dep `TAG` is silently ignored** (Verified) — `cmake/utils/importer.cmake:179-187`
  - Once `<id>-src` exists, `FETCHCONTENT_SOURCE_DIR_<ID>` is cached (`CACHE INTERNAL`, 17 entries after one configure). FetchContent then treats it as a local override and never re-checks out. Only `just clean deps` picks up the new tag.
  - Fix: delete the manual source-dir override and let FetchContent manage update state (`FETCHCONTENT_UPDATES_DISCONNECTED` for offline speed). Keep the "From cache" log by checking `EXISTS` only.
- [ ] **C5 Installed package is broken** (Verified) — `cmake/utils/scaffolding.cmake:59,79,138`
  - Headers are never installed, yet the export advertises `${_IMPORT_PREFIX}/include/px`; consumers get "non-existent path" errors.
  - Fix: `target_sources(... PUBLIC FILE_SET HEADERS BASE_DIRS ... FILES ...)` + `install(TARGETS ... FILE_SET HEADERS)`.
- [ ] **C6 `cmake --install` installs dependency headers/libs** (Verified)
  - Install tree gets cpr, EASTL, ctre, range-v3, httplib, utfcpp, tl, etc.
  - Fix: `EXCLUDE_FROM_ALL` in `FetchContent_Declare` (supported since 3.28). Also stops building unused dep targets by default.
- [x] **C7 `USE_MIMALLOC=ON` fails configure** (Fixed 2026-10-15) — `cmake/configs/malloc.cmake:6`
  - `import_dependency(mimalloc::mimalloc ...)` has no `SUBDIR`; `import_dependency` fatals with `SUBDIR is required`.
  - Fix: add `SUBDIR include`.
- [x] **C30 No tests are registered; `just test` runs nothing** (Fixed 2026-10-15: `setup_testing` is a macro) — `cmake/utils/scaffolding.cmake:113`
  - `enable_testing()` inside `function(setup_testing)` sets `CMAKE_TESTING_ENABLED` in function scope only, so no `CTestTestfile.cmake` is generated (`Total Tests: 0`). Regression from B6 (macros to functions).
  - Fix: make `setup_testing` a `macro()`, or call `enable_testing()` directly in the top-level `CMakeLists.txt`.
- [x] **C8 Preset options stick between presets** (Fixed 2026-10-15)
  - `base` preset resets `ENABLE_ASAN`, `ENABLE_UBSAN`, `FORCE_ERROR`; each preset sets what it varies.
  - Build dirs per group: `.build/{debug,profile,release}` and `*_san` for any sanitizer combo. `profile` = `RelWithDebInfo` (new).
  - Dep build trees moved to `<build>/_deps/`; only sources are shared in `.deps/`. `DEPS_DIR` default is now `<source>/.deps`.
  - CMake writes `.build/active_preset` (preset, binary dir); `just` defaults to it.

## Correctness — Medium

- [ ] **C9 Dep headers not treated as system** (Verified) — `cmake/utils/importer.cmake:31`
  - Wrapper INTERFACE target lives in the caller's directory, so `SYSTEM TRUE` does not apply; own targets get `-I`, not `-isystem`. With the strict warning set and `FORCE_ERROR`, any dep header warning breaks the build.
  - Fix: `target_include_directories(... SYSTEM INTERFACE ...)`.
- [ ] **C10 Global defaults don't reach dependencies** (Verified) — `cmake/base.cmake:51-61`
  - `deps.cmake` runs before `defaults/cache/linker.cmake`. Deps compile without ccache launcher, link without mold, and put DLLs/shared libs outside `bin/` (Windows exes won't find them).
  - Fix: include `cache.cmake`, `linker.cmake`, output-dir settings before `deps.cmake`. Keep warnings/visibility/IPO after (intentionally own-targets only).
- [ ] **C11 Project builds as C++23, not C++20** (Verified)
  - glaze v7 exports `INTERFACE cxx_std_23`; via `all_dependencies` every target gets `-std=c++23`. Rules say C++20.
  - Decide: accept C++23 (update rules, drop `tl::expected` polyfill) or pin a glaze release that supports C++20.
- [ ] **C12 `CCACHE_DIR` has no effect at build time** (Inspected) — `cmake/configs/cache.cmake:10`
  - `set(ENV{...})` only lives during configure; ninja-launched ccache uses the shell env. Works via `just` only because the justfile exports it.
  - Fix: launcher `${CMAKE_COMMAND} -E env CCACHE_DIR=... ${__ccache_found}`, or drop the CMake-side default.
- [ ] **C13 C++-only warnings applied to C sources** (Inspected) — `cmake/configs/warnings.cmake:45`
  - Globs include `*.c`; GCC warns `-Wold-style-cast`/`-Wnon-virtual-dtor`/`-Woverloaded-virtual`/`-Wuseless-cast` are "valid for C++ but not for C".
  - Fix: wrap C++-only flags in `$<$<COMPILE_LANGUAGE:CXX>:...>`.
- [ ] **C14 Generated Config.cmake lacks `find_dependency`** (Inspected) — `cmake/utils/scaffolding.cmake:150`
  - `find_dependency()` used without `include(CMakeFindDependencyMacro)`; any `DEPS` arg yields an unknown-command error in consumers. `set(px_FOUND TRUE)` is redundant; add `check_required_components`.
- [ ] **C15 Fetch guard is dead code** (Inspected) — `cmake/utils/importer.cmake:133,220`
  - `__fetched_<id>` is set in function scope, so it never survives the call. Works only because FetchContent is idempotent. Remove, or use a `GLOBAL` property.
  - Same for `CMAKE_ARGS` (no-op for `MakeAvailable`) and `CMAKE_POLICY_DEFAULT_CMP0135` (only affects URL downloads).
- [ ] **C16 Dead/ineffective state in `base.cmake`** (Verified)
  - `unset(__pre_project_invoked)` clears the normal var only; the `CACHE INTERNAL` entry persists, so the missing-`pre_project()` warning never fires after the first configure. Use a plain variable.
  - `CMAKE_DISABLE_SOURCE_CHANGES` / `CMAKE_DISABLE_IN_SOURCE_BUILD` are undocumented. `CMAKE_DISABLE_SOURCE_CHANGES` is enforced at generate time (it rejected a custom command output in the source root, hence the stamp in C1); `CMAKE_DISABLE_IN_SOURCE_BUILD` is redundant with the explicit in-source check. Decide whether to keep the former; remove the latter.
  - Default `CMAKE_BUILD_TYPE` should be skipped for multi-config generators (`CMAKE_CONFIGURATION_TYPES`).
- [ ] **C17 `import_dependency` OPTIONS that are no-ops** (Inspected) — `cmake/deps.cmake:27-28`
  - asio has no CMakeLists; `ASIO_STANDALONE` / `ASIO_NO_DEPRECATED` become cache vars nobody reads. They are preprocessor macros: add `target_compile_definitions` support (e.g. a `DEFINES` arg) or drop them.
- [ ] **C18 INTERFACE dep targets skipped when linking** (Inspected) — `cmake/utils/importer.cmake:37`
  - Found INTERFACE targets (not under `ns::target`) are not linked, dropping their compile definitions/features/transitive deps. Link them too.

## Correctness — Low

- [ ] **C19 Glob manifest adds little** — `cmake/utils/manifest.cmake`, `CMakeLists.txt:18-20`
  - Manifest is rewritten at the end of every configure, so `check_manifest` only reports what `CONFIGURE_DEPENDS` already handled; `stale-check` in CI never fails after a fresh configure. Scan is recursive while `__glob_sources` is not, so files in subdirs are tracked but never compiled.
  - Decide: remove (YAGNI), or make globs recursive and compare against the glob results instead of a rescan.
- [ ] **C20 `stale-check.cmake` root walk can loop forever** — `cmake/stale-check.cmake:24`
  - `get_filename_component(DIRECTORY)` of `/` is `/`, never `""`. Compare against previous value. Error message names `build_dir` instead of the script dir. Missing manifest exits 0 (CI passes with no build).
- [ ] **C21 Root-dir assumptions break use as a subproject**
  - `CMAKE_SOURCE_DIR` used for vendor, ccache dir, compile_commands copy, manifest. Use `PROJECT_SOURCE_DIR`; gate `add_subdirectory(tests)` on `PROJECT_IS_TOP_LEVEL` (or `BUILD_TESTING`).
- [ ] **C22 `setup_export(NAMESPACE)` mismatch** — `scaffolding.cmake:9,126`
  - Libs already captured `include/${__export_namespace}` before `NAMESPACE` changes it.
- [ ] **C23 mimalloc helper issues** — `cmake/configs/malloc.cmake`
  - `${mimalloc_BINARY_DIR}` is undefined (project is `libmimalloc`, fetch id `microsoft_mimalloc`); use `$<TARGET_FILE_DIR:mimalloc>`.
  - Warning suppressions re-applied to `mimalloc` on every `target_link_mimalloc` call; move next to the import.
- [ ] **C24 Sanitizers on MSVC** — `cmake/configs/sanitizers.cmake`
  - `-fsanitize=` passed to `link.exe` (ignored with LNK4044); UBSan unsupported. Add `-fno-omit-frame-pointer` for usable ASan traces.
- [ ] **C25 mold flag not checked** — `cmake/configs/linker.cmake`
  - GCC < 12.1 rejects `-fuse-ld=mold`. Use `check_linker_flag`, or `CMAKE_LINKER_TYPE` once min is 3.29.
- [ ] **C26 `PATCH` path is fragile** — `importer.cmake:157-177`
  - `git clone --branch` fails for commit-hash tags; `PATCH` undocumented in the header comment. `GIT_SHALLOW TRUE` also fails for hashes.
- [ ] **C27 justfile nits**
  - `_list_all` calls missing recipe `_list_base` (`just list all` fails).
  - `run` uses `find -perm -u+x` (no Windows).
- [ ] **C28 Docs drift in comments** — `warnings.cmake:11` (`/Zc:preprocessor` is not two-phase lookup; that's `/permissive-`), `defaults.cmake:36` (says "Set modules flags" but disables scanning), `-Wno-float-equal` / `-Wno-c++98-compat*` disable warnings that are never enabled.
- [ ] **C29 Every target links every dep** — `all_dependencies`
  - All compiled deps (fmt, cpr, EASTL, glm) link into every exe/test. Consider per-target `DEPS` args on `make_*`.

## Missing features (carried over from `rework.md`)

- [ ] **MF1** Cross-compilation / toolchain support (ref: Corrosion, Hunter)
- [ ] **MF2** `pkg-config` generation (ref: cmake-init)
- [ ] **MF3** CPack packaging
- [ ] **MF4** Feature detection (`check_*`), clang-tidy/cppcheck hooks
- [ ] **MF5** Minimum compiler version validation
- [ ] **MF6** Multi-config generator handling (`CMAKE_BUILD_TYPE` checks, compile_commands, ctest `-C`)
- [ ] **MF7** `try_compile` / C++20 feature validation
- [ ] **MF8** CI presets: `buildPresets`, `testPresets` (generator now in presets)
- [ ] **MF9** `find_package` fallback for system deps (ref: `CPMFindPackage`, FetchContent `FIND_PACKAGE_ARGS`)
- [ ] **MF10** `target_compile_features(cxx_std_20)` instead of global `CMAKE_CXX_STANDARD`
- [ ] **MF11** Opt-in local packages (ref: `CPM_USE_LOCAL_PACKAGES`); overlaps MF9
- [ ] **MF12** Dep pinning/update strategy (lock file); see C4
- [ ] **MF13** `CMAKE_INSTALL_PREFIX` default/validation, install presets
- [ ] **MF14** Clear diagnostics for dep fetch/version failures

## Tooling / AI friendliness

- [ ] **T1** `.clang-format` matching current style (2-space, attached braces), so style rules are enforced, not described.
- [ ] **T2** CI workflow: configure + build + `ctest` on `debug-strict` and `debug-sanitizers` (C1, C8 done).

## Suggested order

1. ~~C1, C2, C7, C30~~ (one-liners that unblock basic use)
2. ~~C8~~, C4, C10 (dev-loop correctness)
3. C3, C5, C6, C14 (install/export story)
4. C9, C11, C13 (strict warnings actually usable)
5. Rest, then MF items

## Key decisions (kept from `rework.md`)

- `SUBDIR` required per dep; no auto-detection.
- OPTIONS use `CACHE FORCE`: only way to override dep cache entries before `add_subdirectory`.
- Dep build type: plain `set(CMAKE_BUILD_TYPE)` in function scope, not `CACHE FORCE` (avoids reconfigure loops).
- `CACHE INTERNAL` for `__export_targets`: cross-subdir state sharing.
- Warning flags `PRIVATE`; never leak to consumers.
- mimalloc: targeted `-Wno-*`, not blanket `-w`.
- No `CMAKE_DEBUG_POSTFIX` (conflicts with per-dep build types).
