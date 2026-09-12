# CMake Wrapper Audit — release_deps

## Architecture Summary

22 files, ~1,188 lines. 16 deps, 8 options, 5 target macros. Well-structured modular layout under `cmake/`.

### File Inventory

| #   | File Path                              | Lines     |
| --- | -------------------------------------- | --------- |
| 1   | `cmake/base.cmake`                     | 70        |
| 2   | `cmake/deps.cmake`                     | 195       |
| 3   | `cmake/utils/scaffolding.cmake`        | 179       |
| 4   | `cmake/utils/logger.cmake`             | 57        |
| 5   | `cmake/utils/importer.cmake`           | 228       |
| 6   | `cmake/configs/linker.cmake`           | 15        |
| 7   | `cmake/configs/defaults.cmake`         | 42        |
| 8   | `cmake/configs/options.cmake`          | 37        |
| 9   | `cmake/configs/compile_commands.cmake` | 20        |
| 10  | `cmake/configs/warnings.cmake`         | 102       |
| 11  | `cmake/configs/cache.cmake`            | 15        |
| 12  | `cmake/configs/sanitizers.cmake`       | 18        |
| 13  | `cmake/configs/malloc.cmake`           | 67        |
| 14  | `CMakeLists.txt`                       | 24        |
| 15  | `projects/CMakeLists.txt`              | 1         |
| 16  | `projects/core/CMakeLists.txt`         | 1         |
| 17  | `tests/CMakeLists.txt`                 | 3         |
| 18  | `tests/test_core/CMakeLists.txt`       | 2         |
| 19  | `tests/test_malloc/CMakeLists.txt`     | 4         |
| 20  | `tests/test_app/CMakeLists.txt`        | 1         |
| 21  | `CMakePresets.json`                    | 75        |
| 22  | `cmake/patches/.gitkeep`               | 0         |
| 23  | `cmake/utils/manifest.cmake`           | 107 (new) |
| 24  | `cmake/stale-check.cmake`              | 42 (new)  |
| 25  | `justfile`                             | 152       |

---

## Progress

| #   | Item                                      | Status        | Date       | Notes                                                                                                                                                                                                                                                                                                                                 |
| --- | ----------------------------------------- | ------------- | ---------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| B2  | `file(GLOB)` for include-subdir detection | **Done**      | 2026-09-07 | Deleted `__detect_include_subdir` (58 lines). SUBDIR now required per dep. `importer.cmake` 316→228, `deps.cmake` 179→195. Net -65 lines. Zero auto-detection.                                                                                                                                                                        |
| B1  | `file(GLOB)` for source collection        | **Mitigated** | 2026-09-07 | `CONFIGURE_DEPENDS` stays. `cmake/utils/manifest.cmake` (107 lines: scan/write/read/check, uses logger helpers). `cmake/stale-check.cmake` (42 lines, raw message() for script mode). `check_manifest()` in CMakeLists.txt warns. `just stale-check` fatals. One diff function, two callers. Manifest renamed to `glob_manifest.txt`. |
| B3  | Global `CMAKE_CXX_FLAGS=-O3`              | **Done**      | 2026-09-08 | Removed `DEPS_FORCE_OPTIMIZATION` option entirely. `DEPS_BUILD_TYPE=Release` already provides `-O3` via CMake's default `CMAKE_CXX_FLAGS_RELEASE`. Redundant and harmful — replaced entire `CMAKE_CXX_FLAGS` variable.                                                                                                                |
| B4  | Global `CACHE FORCE` for OPTIONS          | **Done**      | 2026-09-08 | CACHE FORCE is the only mechanism to override dep-defined cache entries before `add_subdirectory`. Moved OPTIONS parsing before fetch guard. CMAKE_ARGS is a no-op for FetchContent `add_subdirectory` paths.                                                                                                                         |
| B9  | LTO without `check_ipo_supported()`       | **Done**      | 2026-09-12 | `defaults.cmake:26-34` now calls `check_ipo_supported()` via `CheckIPOSupported` module. Warning (not fatal) on unsupported compilers.                                                                                                                                                                                               |
| B11 | Hard-coded `-O3` override for deps        | **Done**      | 2026-09-08 | Removed in `a218e66` ("better flags +"). `importer.cmake` no longer contains `-O3` override.                                                                                                                                                                                                                                        |

### Key Decisions

- SUBDIR is required — no auto-detection. Explicit paths for all deps.
- Stale check warns at configure time (non-blocking), fatals in CI via `just stale-check`.
- `manifest.cmake` includes `logger.cmake` and uses `log_status`/`log_warning`/`log_fatal`.
- `stale-check.cmake` keeps raw `message()` — runs in `cmake -P` script mode without project context.
- `check_manifest(path [FATAL])` — single diff function, CMakeLists.txt calls without FATAL, stale-check.cmake calls with FATAL.
- Manifest is always written after check — prevents infinite configure loops on staleness.

### Current Line Counts (post-changes)

| #   | File Path                    | Lines | Delta |
| --- | ---------------------------- | ----- | ----- |
| 2   | `cmake/deps.cmake`           | 195   | +16   |
| 5   | `cmake/utils/importer.cmake` | 224   | -92   |
| —   | `cmake/utils/manifest.cmake` | 107   | new   |
| —   | `cmake/stale-check.cmake`    | 41    | new   |
| 14  | `CMakeLists.txt`             | 24    | +5    |
| —   | `justfile`                   | 152   | +4    |
| 7   | `cmake/configs/defaults.cmake` | 48  | +6    |

All other files unchanged.

### Positive Practices Found

- Target-based design — no directory-scoped `include_directories()` / `link_directories()`
- `include_guard(DIRECTORY)` in all modules
- `cmake_minimum_required(VERSION 3.28)` — recent baseline
- Generator expressions for BUILD_INTERFACE / INSTALL_INTERFACE
- `cmake_parse_arguments` in `import_dependency()` and `setup_export()`
- `FetchContent` + `GIT_SHALLOW TRUE` + `SYSTEM TRUE`
- Export/install support via `setup_export()`
- `GNUInstallDirs` for portable install paths
- Well-structured `CMakePresets.json`
- `PROJECT_IS_TOP_LEVEL` gating for test enablement
- In-source build guard
- `CMAKE_EXPORT_COMPILE_COMMANDS` with symlink management
- Per-compiler-specific warning flags
- Sanitizer flags propagated to both compile and link
- Dependency version pinning via exact TAGs
- No TODO/FIXME/HACK comments

---

## Bad Practices

| #   | Issue                                                        | Location                           | Severity            | Status                                                                                                                                                                                                      |
| --- | ------------------------------------------------------------ | ---------------------------------- | ------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| B1  | `file(GLOB)` for source collection                           | `scaffolding.cmake:15-22`          | **High**            | **Mitigated** — CONFIGURE_DEPENDS + manifest stale check                                                                                                                                                    |
| B2  | ~~`file(GLOB)` for include-subdir detection~~                | ~~`importer.cmake`~~               | ~~Low~~             | **Resolved** — SUBDIR required per dep                                                                                                                                                                      |
| B3  | ~~Global `CMAKE_CXX_FLAGS=-O3` for dep optimization~~        | ~~`importer.cmake:219-221`~~       | ~~\*\*High~~\*\*    | **Resolved** — Removed `DEPS_FORCE_OPTIMIZATION`. `DEPS_BUILD_TYPE=Release` already provides `-O3` via CMake defaults.                                                                                      |
| B4  | ~~Global `CACHE FORCE` writes for dep OPTIONS~~              | ~~`importer.cmake:234-235`~~       | ~~\*\*High~~\*\*    | **Resolved** — OPTIONS use CACHE FORCE (only mechanism to override dep cache entries before `add_subdirectory`). Moved before fetch guard. CMAKE_ARGS is a no-op for FetchContent `add_subdirectory` paths. |
| B5  | `CACHE INTERNAL` state for target tracking                   | `scaffolding.cmake:9-10`           | Medium              | Open                                                                                                                                                                                                        |
| B6  | `macro()` where `function()` would be safer                  | `scaffolding.cmake:26,48,73,87,92` | Medium              | Open                                                                                                                                                                                                        |
| B7  | Warning flags set `PUBLIC` — leaks to consumers              | `warnings.cmake:95-99`             | **High** (for libs) | Open                                                                                                                                                                                                        |
| B8  | `CMAKE_WINDOWS_EXPORT_ALL_SYMBOLS` — crutch                  | `defaults.cmake:34`                | Medium              | Open                                                                                                                                                                                                        |
| B9  | ~~LTO set without `check_ipo_supported()`~~                    | ~~`defaults.cmake:26-28`~~         | ~~\*\*High~~\*\*    | **Resolved** — `defaults.cmake:26-34` now calls `check_ipo_supported()` via `CheckIPOSupported` module. Warning (not fatal) on unsupported compilers.                                                                                                                               |
| B10 | mimalloc warnings suppressed via `-w`                        | `malloc.cmake:32-35`               | Low                 | Open                                                                                                                                                                                                        |
| B11 | ~~Hard-coded `-O3` override for all deps~~                    | ~~`importer.cmake:217-223`~~       | ~~Medium~~          | **Resolved** — Removed in `a218e66` ("better flags +"). Lines no longer contain `-O3` override.                                                                                                                                                                         |
| B12 | `__base_dir` set CACHE INTERNAL then unset                   | `base.cmake:9,67`                  | Low                 | Open                                                                                                                                                                                                        |
| B13 | `file(MAKE_DIRECTORY "$ENV{CCACHE_DIR}")` — no guard         | `cache.cmake:9`                    | Low                 | Open                                                                                                                                                                                                        |
| B14 | `CMAKE_POLICY_VERSION_MINIMUM 3.10` — masks policy issues    | `importer.cmake:7-8`               | Low                 | Open                                                                                                                                                                                                        |
| B15 | `compile_commands.json` symlink — no fallback on non-Windows | `compile_commands.cmake:11-16`     | Low                 | Open                                                                                                                                                                                                        |

### Top 3 Impact

1. **B7** — warning flags leak to downstream consumers
2. **B6** — macro scope leaks requiring CACHE INTERNAL workarounds
3. **B5** — `CACHE INTERNAL` state for target tracking

---

## Missing Features

| #    | Gap                                                              | Comparison Reference                                         |
| ---- | ---------------------------------------------------------------- | ------------------------------------------------------------ |
| MF1  | No cross-compilation / toolchain support                         | Corrosion, Hunter have first-class                           |
| MF2  | No `pkg-config` generation                                       | cmake-init generates `.pc` patterns                          |
| MF3  | No CPack packaging                                               | Standard in cmake-init templates                             |
| MF4  | No feature detection (`check_*` calls)                           | Corrosion uses `FindRust`; cmake-init has sanitizers/linting |
| MF5  | No compiler version validation                                   | cmake-init validates minimum compiler                        |
| MF6  | No multi-config generator handling for compile_commands          | FetchContent handles this correctly                          |
| MF7  | No `try_compile` / compile feature validation                    | cmake-init validates C++20 features                          |
| MF8  | No CI/CD presets or hints                                        | cmake-init generates CI-ready presets                        |
| MF9  | No `find_package` fallback for system deps                       | CPM.cmake has `CPMFindPackage()`                             |
| MF10 | Uses `CMAKE_CXX_STANDARD` instead of `target_compile_features()` | cmake-init, Corrosion use `target_compile_features`          |
| MF11 | All deps unconditionally fetched — no system package fallback    | CPM.cmake: `CPM_USE_LOCAL_PACKAGES`                          |
| MF12 | No FetchContent update/pinning strategy                          | CPM.cmake: package lock files                                |
| MF13 | No `CMAKE_INSTALL_PREFIX` default/validation                     | cmake-init generates install presets                         |
| MF14 | No diagnostic messages for dep failures                          | CPM.cmake: clear version conflict warnings                   |

---

## Comparison vs Popular Wrappers

| Aspect                    | This Repo               | cmake-init             | CPM.cmake          | Corrosion        | FetchContent           |
| ------------------------- | ----------------------- | ---------------------- | ------------------ | ---------------- | ---------------------- |
| **Dep download**          | Custom `importer.cmake` | N/A (template)         | FetchContent       | Cargo            | ExternalProject        |
| **Cross-compile**         | None                    | Correct structure      | Pass-through       | First-class      | Pass-through           |
| **Version pinning**       | GIT_TAG per dep         | cmake_min_required     | Tags/commits/lock  | Cargo.lock       | GIT_TAG                |
| **Binary cache**          | None                    | N/A                    | `CPM_SOURCE_CACHE` | N/A              | None                   |
| **find_package fallback** | All FetchContent        | Optional (conan/vcpkg) | `CPMFindPackage()` | N/A              | `FIND_PACKAGE_ARGS`    |
| **Install/Export**        | `setup_export()`        | Gold standard          | Delegated          | Experimental     | Delegated              |
| **Global state**          | CACHE FORCE writes      | Minimal                | `CPM_*` vars       | `Rust_*` vars    | `FETCHCONTENT_*`       |
| **Macros vs Functions**   | Macros for targets      | Modern idioms          | Functions only     | Functions only   | Functions only         |
| **Feature detection**     | None                    | clang-tidy/cppcheck    | None               | FindRust         | None                   |
| **Offline support**       | None                    | N/A                    | Source cache       | N/A              | `UPDATES_DISCONNECTED` |
| **Policy management**     | Lowers min to 3.10      | Enforces modern        | Forces CMP0077+    | Proper cmake_min | Inherits caller        |

---

## Key Gaps vs Best-in-Class

1. **CPM.cmake solves the "find or fetch" problem** — this repo has no `find_package` fallback. If a system package exists, it is ignored.

2. **cmake-init generates relocatable install packages** — this repo's `setup_export()` is close but lacks `configure_package_config_file()` for relocatable prefix paths.

3. **Corrosion uses functions-only API** — this repo uses macros for `make_*`, which leak scope and require `CACHE INTERNAL` workarounds.

4. **Hunter isolates per-toolchain** — this repo has zero cross-compilation awareness.
