# Configuration

## Presets and checks

Presets are the build types: `debug`, `profile` (RelWithDebInfo) and
`release`. Select one with `just preset=<name> build`; `just` then remembers
the last configured preset. The build goes to `.build/<preset>/`.

Checks are options on top of any preset: sanitizers and warnings as errors.

| `just` | CMake | |
|---|---|---|
| `strict=true` | `-D PX_FORCE_ERRORS=ON` | Warnings are errors (what CI uses). |
| `asan=true` | `-D PX_ENABLE_ASAN=ON` | Out-of-bounds access, use-after-free, leaks on Linux. |
| `ubsan=true` | `-D PX_ENABLE_UBSAN=ON` | Undefined behaviour: overflow, bad casts, null access. |
| `tsan=true` | `-D PX_ENABLE_TSAN=ON` | Data races. 5-15x slower. |
| `msan=true` | `-D PX_ENABLE_MSAN=ON` | Reads of uninitialized memory. Clang only. |
| `lsan=true` | `-D PX_ENABLE_LSAN=ON` | Leaks only, cheap. |

```sh
just asan=true ubsan=true build    # = cmake --preset debug -D PX_ENABLE_ASAN=ON -D PX_ENABLE_UBSAN=ON
just build                         # same checks: the build dir keeps them
just asan=false build              # ASan off, UBSan still on
```

As with any `-D`, a check stays in the build dir's cache until set again
(`--fresh` clears them all). The configure log prints the active ones
(`Sanitizers ->`, `Warnings ->`). In an IDE, set them in its CMake cache
editor or in a personal `CMakeUserPresets.json` (ignored by git):

```json
{
  "version": 8,
  "configurePresets": [
    { "name": "debug-asan", "inherits": "debug",
      "cacheVariables": { "PX_ENABLE_ASAN": "ON", "PX_ENABLE_UBSAN": "ON" } }
  ],
  "buildPresets": [{ "name": "debug-asan", "configurePreset": "debug-asan" }],
  "testPresets": [{ "name": "debug-asan", "configurePreset": "debug-asan" }]
}
```

It builds into `.build/debug-asan/`, so switching to it and back rebuilds
nothing. `just preset=debug-asan build` works with it too.

Sanitizers instrument the project's own targets, not its deps:
- TSan (data races) can't be combined with ASan, MSan or LSan, and misses
  races inside deps. On kernels with high ASLR entropy, older TSan runtimes
  abort at startup with "unexpected memory mapping": lower it
  (`sudo sysctl vm.mmap_rnd_bits=28`) or run with ASLR off
  (`setarch -R <exe>`);
- MSan (uninitialized reads) is Clang only and can't be combined with ASan
  or LSan. Values written by uninstrumented code (deps, the standard
  library) count as uninitialized, so expect false positives;
- LSan (leaks) is already part of ASan on Linux; alone it is the cheap
  leak-only check;
- Windows: MSVC has ASan only, clang-cl ASan and UBSan. ASan turns
  incremental linking off for own targets and copies its runtime DLL
  (`clang_rt.asan_dynamic-<arch>.dll`) next to each exe, so they also run
  outside a developer prompt. Clang's ASan rejects the debug CRT, so with
  clang-cl an ASan build uses the release CRT (`/MD`, or `/MT` if
  `CMAKE_MSVC_RUNTIME_LIBRARY` asks for the static one) for the whole tree,
  deps included; the configure log shows it (`CRT ->`).

Combinations the compilers reject fail at configure.

Options, settable with `-D` or in a preset:

| Option | Default | |
|---|---|---|
| `PX_USE_CCACHE`, `PX_USE_MOLD`, `PX_USE_COMPILE_COMMANDS` | `ON` | Used when found. |
| `PX_ENABLE_ASAN`, `PX_ENABLE_UBSAN`, `PX_ENABLE_TSAN`, `PX_ENABLE_MSAN`, `PX_ENABLE_LSAN` | `OFF` | Sanitizers, see above. Libs pass the sanitizer link flag on to whatever links them. |
| `PX_FORCE_ERRORS` | `OFF` | Warnings as errors (`just strict=true`). |
| `PX_USE_LTO` | `ON` | LTO in Release and RelWithDebInfo, when supported. |
| `PX_DEPS_DIR` | `.deps/` | Where dependency sources live (or `$PX_DEPS_DIR`). |
| `PX_DEPS_BUILD_TYPE` | `Release` | Build type of dependencies. |
| `PX_DIR` | empty | px `framework/` dir to use (or `$PX_DIR`); empty: installed or fetched. |
| `PX_GIT_REPOSITORY`, `PX_GIT_TAG` | px repo, `v<__px_version>` (`cmake/px.cmake`) | px to fetch when not found. |

`compile_commands.json` is copied to the repo root on every build, so clangd
works with no setup.

The presets use Ninja. With a multi-config generator of your own (Ninja
Multi-Config, Visual Studio, Xcode):
- deps build in each config, and `PX_DEPS_BUILD_TYPE` is ignored;
- `ctest` needs `-C <config>`;
- `compile_commands.json` (Ninja only) lists each file once per config;
  clangd uses the first;
- `just run` runs the config `cmake --build` builds by default
  (`CMAKE_DEFAULT_BUILD_TYPE`, else the first configured).

## Customizing

Everything is set from your project, never by editing px:

- The options above: `-D`, or a preset's `cacheVariables`.
- In the root `CMakeLists.txt`, before `post_project()`:
  - `PX_CXX_STANDARD` (default 23);
  - output dirs (`CMAKE_RUNTIME_OUTPUT_DIRECTORY` and the like) and
    `CMAKE_INSTALL_RPATH`: px only sets them when you haven't.
- `PX_EXTRA_WARNINGS`: flags added after px's warnings on every target made
  after it is set, so they can also turn one off (`-Wno-shadow`). Set it in
  the root, or in one target's `CMakeLists.txt` before its `make_*`.
- `CPACK_*` (`CPACK_GENERATOR`, ...): anywhere before `setup_export()`.
- After `post_project()`, any variable px sets for your targets can be set
  again (`set(CMAKE_CXX_VISIBILITY_PRESET default)`).
- After a `make_*`, plain `target_*` calls on it. The real target name is
  `<project>_<name>` for libs (`myproj_util`), or the name for exes and tests.

## Formatting

```sh
just format         # clang-format over projects/ and tests/
just format_check   # fails on unformatted files (CI)
```

Style lives in `.clang-format`. Its `# clang-format-version: <version>` line
pins the clang-format version, since each release formats slightly
differently. A different version warns, and an older major version fails.
`CLANG_FORMAT=<path>` picks a specific binary.
