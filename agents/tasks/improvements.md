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
- [x] **C3 `make_lib` + `setup_export` fails at generate** (Fixed 2026-10-16)
  - `make_lib` links `$<BUILD_INTERFACE:all_dependencies>` PUBLIC: in-tree consumers unchanged, export no longer references deps. Limits: C32, C33.
- [x] **C4 Bumping a dep `TAG` is silently ignored** (Fixed 2026-10-16)
  - Importer owns sources: shallow `git fetch <TAG>` into `DEPS_DIR/<id>-src`, stamp `DEPS_DIR/<id>.stamp` holds `URL@TAG` (+ PATCH SHA1; URL because `fetch_id` drops the host). Stamp mismatch re-fetches and logs `Updated (old => new)`; match reuses offline. FetchContent only runs `add_subdirectory` via `FETCHCONTENT_SOURCE_DIR_<ID>` (normal var, no cache entry).
  - `FETCHCONTENT_BASE_DIR` is now `<build>/_deps`, so nested FetchContent from deps (e.g. EASTL's EABase) is per build dir too.
  - Hardening (verified): fetch + patch happen in `<id>-src.tmp` and are swapped in only when complete (killed configure leaves old source intact); bad TAG fails with the git command and keeps the old source; `file(LOCK)` per dep serializes concurrent configures; a re-fetch refuses to wipe a checkout with local changes (`git status --porcelain`), and PATCH results are committed in the dep checkout so they count as clean.
  - No submodules fetched: current ones are docs/tests only (range-v3 `doc/gh-pages`, function2 googletest, utfcpp ftest).
  - PATCH accepts `.patch`/`.diff` (`git apply`) or a CMake script. Fetched commit tagged `px-base`; the local-edits error prints the `git diff --cached --binary px-base > cmake/patches/<ns>.patch` commands to capture edits (verified end to end, including re-capturing on top of an existing patch).
  - PATCH playground: `cmake/patches/utfcpp.cmake` (script) and `argparse.patch` (diff) add a marker define; `tests/test_patch` fails to compile without them. Docs: `cmake/patches/README.md`.

- [x] **C5 Installed package is broken** (Fixed 2026-10-16)
  - Headers are a `FILE_SET HEADERS` (recursive glob, so `polyfills/` etc. are included), installed per target to `include/<ns>/<target>/`, which is also the exported include dir. Verified with an external consumer project (`find_package(px)`, links `px::core`/`px::bar`/`px::baz`).
- [x] **C6 `cmake --install` installs dependency headers/libs** (Fixed 2026-10-16)
  - `EXCLUDE_FROM_ALL` in `FetchContent_Declare`; install tree now holds only px headers, libs, and CMake package files.
  - Not covered: shared deps needed at runtime by installed executables (e.g. `libmimalloc.so` with `USE_MIMALLOC=ON`) are not installed either. Would need `install(TARGETS ... RUNTIME_DEPENDENCIES)` or `install(IMPORTED_RUNTIME_ARTIFACTS)`.
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

- [x] **C9 Dep headers not treated as system** (Fixed 2026-10-16)
  - Wrapper include dirs are `SYSTEM INTERFACE`. Verified: a target including one header of every dep under `debug-strict` went from 139 errors (sign-conversion, old-style-cast, conversion, useless-cast, undef) to 0, GCC and Clang.
- [x] **C10 Global defaults don't reach dependencies** (Fixed 2026-10-16)
  - New "Toolchain" stage before deps: `cache.cmake`, `linker.cmake`, `global.cmake` (PIC + output dirs). Deps now get ccache, mold, `-fPIC` (static deps link into SHARED libs), and `bin/`/`lib/` outputs.
- [x] **C11 Project builds as C++23, not C++20** (Resolved 2026-10-17: C++23 adopted)
  - glaze v7 requires `cxx_std_23`. Default `CMAKE_CXX_STANDARD` is now 23, rules updated, `tl::expected` dep dropped (unused; `std::expected` instead).
  - Raises the compiler floor (`std::expected`: GCC 12, Clang 16, MSVC 19.33); see MF5.
- [x] **C12 `CCACHE_DIR` has no effect at build time** (Fixed 2026-10-18)
  - Launcher is `ccache cache_dir=<dir>` (ccache 4.8+ key=value syntax); default `<source>/.cache/ccache`, `CCACHE_DIR` env at configure overrides. justfile no longer exports `CCACHE_DIR`/`DEPS_DIR`. Verified: plain cmake with no env, clean rebuild 46/46 hits.
- [x] **C13 C++-only warnings applied to C sources** (Fixed 2026-10-16)
  - `-Wnon-virtual-dtor`, `-Wold-style-cast`, `-Woverloaded-virtual`, `-Wuseless-cast` wrapped in `$<$<COMPILE_LANGUAGE:CXX>:...>`. Verified: a `.c` file in a target no longer triggers "valid for C++/ObjC++ but not for C".
- [x] **C14 Generated Config.cmake lacks `find_dependency`** (Fixed 2026-10-16)
  - `include(CMakeFindDependencyMacro)` when `DEPS` given, `check_required_components(<ns>)`, dropped the redundant `_FOUND`. Verified with `setup_export(DEPS Threads)`.
- [x] **C15 Fetch guard is dead code** (Fixed 2026-10-16, with C4: guard, `CMAKE_ARGS`, `CMP0135` removed)
- [x] **C16 Dead/ineffective state in `base.cmake`** (Fixed 2026-10-21)
  - ~~`unset(__pre_project_invoked)` clears the normal var only; the `CACHE INTERNAL` entry persists, so the missing-`pre_project()` warning never fires after the first configure.~~ Fixed 2026-10-21: plain `__pre_project_done` var (renamed so stale cache entries can't mask it).
  - ~~`CMAKE_DISABLE_IN_SOURCE_BUILD` redundant with the explicit in-source check.~~ Removed 2026-10-21. `CMAKE_DISABLE_SOURCE_CHANGES` kept (decided 2026-10-21): with recursive globs, files generated into a project dir would be compiled; the flag makes that a configure error. Cost: the `compile_commands` stamp.
  - Multi-config `CMAKE_BUILD_TYPE`: fixed 2026-10-21. No default on multi-config generators; LTO via `CMAKE_INTERPROCEDURAL_OPTIMIZATION_{RELEASE,RELWITHDEBINFO}`; `DEPS_BUILD_TYPE` skipped there (deps build with the selected config); log shows the config list.
- [x] **C17 `import_dependency` OPTIONS that are no-ops** (Fixed 2026-10-18)
  - New `DEFINES` arg: INTERFACE compile definitions on `all_dependencies` (px-owned; dep targets are never modified). Consumer side only; ABI-affecting macros of compiled deps belong in OPTIONS. asio uses `DEFINES ASIO_STANDALONE ASIO_NO_DEPRECATED`, verified on consumer compile lines. OPTIONS on a dep without CMakeLists.txt now warn.
- [x] **C18 INTERFACE dep targets skipped when linking** (Fixed 2026-10-18)
  - Found targets are linked regardless of type. Only phmap was affected (its INTERFACE target carries nothing today), so latent.
  - Noticed: lookup misses deps whose targets use another namespace (utfcpp exports `utf8cpp::utf8cpp`, function2 `function2::function2`); they work through the include dir only. A `TARGET` arg to name the real target would close it if one ever carries usage requirements.
- [ ] **C32 Installed static libs using compiled deps can't be linked** (Verified)
  - Deps are not installed (C6) and not in the export (C3), so a consumer of an installed `STATIC` px lib that calls into e.g. fmt gets `undefined reference to fmt::v11::vformat`. Header-only deps and SHARED libs are fine.
  - Options: `find_dependency` + `$<LINK_ONLY:...>` against system/installed deps (needs MF9), install the compiled deps alongside, or document "install STATIC libs only when dep-free".
- [x] **C33 SHARED px libs re-export symbols of static deps** (Fixed 2026-10-18)
  - `LINKER:--exclude-libs,ALL` on SHARED `make_lib` targets (not Apple/MSVC). Verified: fmt symbols exported by a test `libbaz.so` 100 before, 0 after; own API still exported.
- [ ] **C34 macOS: SHARED px libs still re-export symbols of static deps** (Inspected) — `cmake/utils/scaffolding.cmake` (`make_lib`)
  - The C33 fix (`--exclude-libs,ALL`) is skipped on Apple: ld64 has no such flag. Mach-O dylibs export every default-visibility symbol, including those of static deps linked in (fmt, cpr, EASTL, glm), so a px dylib can clash with or accidentally satisfy a consumer's own copy. Builds still work; it is a correctness/ODR risk, not a link failure.
  - Not an issue on Windows: DLLs export only `dllexport`'d symbols, and static deps carry none. MinGW (GNU ld auto-export) already gets the flag.
  - Options:
    - `-Wl,-hidden-l<name>` per static dep: needs each dep's archive name; fits linking by name only.
    - `-Wl,-load_hidden,$<TARGET_FILE:dep>` per static dep: exact, via generator expressions over the static targets in `all_dependencies` (needs collecting them in `import_dependency`).
    - `-Wl,-exported_symbols_list,<file>`: export only the lib's own API; needs a maintained list or one generated from the lib's objects.
    - Hidden visibility for static deps (`CXX_VISIBILITY_PRESET hidden` on their targets): cross-platform, but only reaches the target the lookup finds, not every target a dep creates.
  - Recommendation: `-load_hidden` over the static dep targets, verified on a Mac (`nm -gU libbaz.dylib | grep fmt` should be empty). Not attempted without one.
- [ ] **C31 Damaged dep sources go unnoticed** — `cmake/utils/importer.cmake` (cache path)
  - When the stamp matches, the source dir is trusted blindly: deleted or modified tracked files (partial `rm`, a tool writing into `.deps/`, a debugging edit left behind) are not detected. Build errors then point at the dep, not at the cause.
  - Option A: run `git status --porcelain` on the cache path too. Measured on the 16 current deps: ~40 ms total warm, up to ~40 ms per large dep cold (range-v3, glaze, glm). Catches tracked-file deletions/edits; does not catch `.git` damage or added untracked files (those don't break builds).
  - Option B: `git fsck` catches `.git` damage too, but costs seconds per configure. Not worth it.
  - Severity choice: a dirty cache hit is also the legit "hack a dep to debug" workflow, so warn there (and keep the re-fetch path fatal, as in C4). A `DEPS_STRICT`-style option could turn the warning fatal for CI.
  - Recommendation: A, as a warning, listing the changed files.

- [x] **C19 Glob manifest adds little** (Fixed 2026-10-21: `manifest.cmake`, `stale-check.cmake` and `just stale-check` removed; `CONFIGURE_DEPENDS` covers it) — `cmake/utils/manifest.cmake`, `CMakeLists.txt:18-20`
  - Manifest is rewritten at the end of every configure, so `check_manifest` only reports what `CONFIGURE_DEPENDS` already handled; `stale-check` in CI never fails after a fresh configure. Scan is recursive while `__glob_sources` is not, so files in subdirs are tracked but never compiled.
  - 2026-10-21: source globs are now recursive, so manifest and build agree on which files exist. Still mostly redundant with `CONFIGURE_DEPENDS`.
  - Decide: remove (YAGNI), or compare against the actual glob results instead of a rescan.
- [x] **C20 `stale-check.cmake` root walk can loop forever** (Fixed 2026-10-21: script removed with C19) — `cmake/stale-check.cmake:24`
  - `get_filename_component(DIRECTORY)` of `/` is `/`, never `""`. Compare against previous value. Error message names `build_dir` instead of the script dir. Missing manifest exits 0 (CI passes with no build).
- [ ] **C21 Root-dir assumptions break use as a subproject**
  - `CMAKE_SOURCE_DIR` used for vendor, ccache dir, compile_commands copy. Use `PROJECT_SOURCE_DIR`; gate `add_subdirectory(tests)` on `PROJECT_IS_TOP_LEVEL` (or `BUILD_TESTING`).
- [x] **C22 `setup_export(NAMESPACE)` mismatch** (Fixed 2026-10-16, with C5: install include dir is computed in `setup_export`)
- [ ] **C23 mimalloc helper issues** — `cmake/configs/malloc.cmake`
  - `${mimalloc_BINARY_DIR}` is undefined (project is `libmimalloc`, fetch id `microsoft_mimalloc`); use `$<TARGET_FILE_DIR:mimalloc>`.
  - Warning suppressions re-applied to `mimalloc` on every `target_link_mimalloc` call; move next to the import.
- [ ] **C24 Sanitizers on MSVC** — `cmake/configs/sanitizers.cmake`
  - `-fsanitize=` passed to `link.exe` (ignored with LNK4044); UBSan unsupported. Add `-fno-omit-frame-pointer` for usable ASan traces.
- [ ] **C25 mold flag not checked** — `cmake/configs/linker.cmake`
  - GCC < 12.1 rejects `-fuse-ld=mold`. Use `check_linker_flag`, or `CMAKE_LINKER_TYPE` once min is 3.29.
- [x] **C26 `PATCH` path is fragile** (Fixed 2026-10-16, with C4: commit SHAs supported, PATCH runs once per fetch and is documented)
- [ ] **C27 justfile nits** (2026-10-18: `build`/`test` use `--preset`; `test` got `pipefail`, it used to exit 0 on failing tests)
  - `run` uses `find -perm -u+x` (no Windows).
- [ ] **C28 Docs drift in comments** — `warnings.cmake:11` (`/Zc:preprocessor` is not two-phase lookup; that's `/permissive-`), `defaults.cmake:36` (says "Set modules flags" but disables scanning), `-Wno-float-equal` / `-Wno-c++98-compat*` disable warnings that are never enabled.
- [ ] **C29 Every target links every dep** — `all_dependencies`
  - All compiled deps (fmt, cpr, EASTL, glm) link into every exe/test. Consider per-target `DEPS` args on `make_*`.
  - When doing this: `import_dependency` DEFINES currently land on `all_dependencies` (px-owned, so dep targets are never modified). Per-target linking must move them onto a px-owned handle per dep (e.g. `__dep_<ns>_<target>` linking the real target and holding SYSTEM includes + DEFINES), since `ns::target` is taken when the dep provides its own alias. Targets would then link those handles instead of `ns::target`.

## Missing features (carried over from `rework.md`)

- [ ] **MF1** Cross-compilation / toolchain support (ref: Corrosion, Hunter)
- [ ] **MF2** `pkg-config` generation (ref: cmake-init)
- [ ] **MF3** CPack packaging
- [ ] **MF4** Feature detection (`check_*`), clang-tidy/cppcheck hooks
- [ ] **MF5** Minimum compiler version validation
- [ ] **MF6** Multi-config generator handling (compile_commands, ctest `-C`; build-type checks done in C16)
- [ ] **MF7** `try_compile` / C++23 feature validation
- [x] **MF8** CI presets: `buildPresets`, `testPresets` for every configure preset (2026-10-18); test presets use `noTestsAction: error`
- [ ] **MF9** `find_package` fallback for system deps (ref: `CPMFindPackage`, FetchContent `FIND_PACKAGE_ARGS`)
- [ ] **MF10** `target_compile_features(cxx_std_23)` instead of global `CMAKE_CXX_STANDARD`
- [ ] **MF11** Opt-in local packages (ref: `CPM_USE_LOCAL_PACKAGES`); overlaps MF9
- [ ] **MF12** Dep lock file (resolved SHA per dep); per-dep stamps from C4 are the base
- [ ] **MF13** `CMAKE_INSTALL_PREFIX` default/validation, install presets
- [ ] **MF14** Clear diagnostics for dep fetch/version failures

## Tooling / AI friendliness

- [ ] **T1** `.clang-format` matching current style (2-space, attached braces), so style rules are enforced, not described.
- [x] **T2** CI workflow (2026-10-18, `.github/workflows/ci.yml`: GitHub Actions, Ubuntu 24.04, {gcc, clang} x `debug-sanitizers-strict`, skipped for doc-only changes, caches `.deps` and ccache): configure + build + `ctest` on `debug-strict` and `debug-sanitizers` (C1, C8 done).

## Suggested order

1. ~~C1, C2, C7, C30~~ (one-liners that unblock basic use)
2. ~~C8, C4, C10~~ (dev-loop correctness)
3. ~~C3, C5, C6, C14~~ (install/export story); follow-ups C32, C33
4. ~~C9, C13, C11~~ (strict warnings actually usable)
5. Rest, then MF items

## Key decisions (kept from `rework.md`)

- `SUBDIR` required per dep; no auto-detection.
- OPTIONS use `CACHE FORCE`: only way to override dep cache entries before `add_subdirectory`.
- Dep sources managed by the importer (not FetchContent downloads), keyed by a URL/TAG/PATCH stamp; shared across build dirs, build trees never shared.
- Dep build type: plain `set(CMAKE_BUILD_TYPE)` in function scope, not `CACHE FORCE` (avoids reconfigure loops).
- `CACHE INTERNAL` for `__export_targets`: cross-subdir state sharing.
- Warning flags `PRIVATE`; never leak to consumers.
- mimalloc: targeted `-Wno-*`, not blanket `-w`.
- No `CMAKE_DEBUG_POSTFIX` (conflicts with per-dep build types).
