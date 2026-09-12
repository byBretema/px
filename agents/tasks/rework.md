# CMake Wrapper Audit — release_deps

> Audit px cmake wrapper: fix bad practices, close gaps vs CPM.cmake/cmake-init/Corrosion

## Status

| # | Item | Status | Date |
|---|------|--------|------|
| B1 | `file(GLOB)` source collection | **Mitigated** | 2026-09-07 |
| B2 | `file(GLOB)` include-subdir detection | **Done** | 2026-09-07 |
| B3 | Global `CMAKE_CXX_FLAGS=-O3` | **Done** | 2026-09-08 |
| B4 | Global `CACHE FORCE` for OPTIONS | **Done** | 2026-09-08 |
| B5 | `CACHE INTERNAL` target tracking | **Done** | 2026-09-12 |
| B6 | Macros leaked scope | **Done** | 2026-09-12 |
| B7 | Warning flags `PUBLIC` leak | **Done** | 2026-09-12 |
| B8 | `CMAKE_WINDOWS_EXPORT_ALL_SYMBOLS` | **Done** | 2026-09-12 |
| B9 | LTO without `check_ipo_supported()` | **Done** | 2026-09-12 |
| B10 | mimalloc blanket `-w` suppression | **Done** | 2026-09-12 |
| B11 | Hard-coded `-O3` override for deps | **Done** | 2026-09-08 |
| B12 | Dead `unset(__base_dir)` | **Done** | 2026-09-12 |
| B13 | CCACHE_DIR unguarded mkdir | **Done** | 2026-09-12 |
| B14 | `CMAKE_POLICY_VERSION_MINIMUM 3.10` | **Open** | — |
| B15 | `compile_commands.json` symlink | **Done** | 2026-09-12 |

## Next

- **B14** — Scope `CMAKE_POLICY_VERSION_MINIMUM` per-dep in `importer.cmake` (set/unset around `FetchContent_MakeAvailable`)

## Remaining (Low)

- MF1–MF14 missing features (cross-compile, pkg-config, CPack, find_package fallback, etc.)

## Changes Summary

| File | Lines | Delta |
|------|-------|-------|
| `cmake/utils/importer.cmake` | 224 | -92 |
| `cmake/utils/manifest.cmake` | 107 | new |
| `cmake/stale-check.cmake` | 41 | new |
| `cmake/deps.cmake` | 195 | +16 |
| `cmake/configs/defaults.cmake` | 46 | +4 |
| `cmake/configs/warnings.cmake` | 102 | unchanged (`PUBLIC`→`PRIVATE`) |
| `cmake/configs/malloc.cmake` | 69 | +2 |
| `cmake/configs/compile_commands.cmake` | 11 | -9 |
| `cmake/configs/cache.cmake` | 17 | +2 |
| `cmake/base.cmake` | 69 | -1 |
| `cmake/utils/scaffolding.cmake` | 179 | unchanged (macros→functions) |
| `CMakeLists.txt` | 24 | +5 |
| `justfile` | 155 | +4 |

## Key Decisions

- SUBDIR required per dep — no auto-detection
- Stale check: warns at configure, fatals in CI via `just stale-check`
- Manifest always written after check — prevents infinite configure loops
- `CACHE INTERNAL` for `__export_targets` — correct for cross-subdir state sharing (not a workaround)
- Warning flags `PRIVATE` — never leak to consumers
- mimalloc: targeted `-Wno-*`, not blanket `-w`
- `CCACHE_DIR` defaults to `${CMAKE_SOURCE_DIR}/.cache/ccache` (matches justfile)
- `compile_commands.json`: simple copy, no symlinks
