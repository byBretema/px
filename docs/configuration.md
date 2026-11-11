# Configuration

## Presets

Presets are named `<type>[-<sanitizer>][-strict]`:

- type: `debug`, `profile` (RelWithDebInfo), `release`;
- sanitizer: `asan`, `ubsan`, `sanitizers` (both);
- `strict`: warnings are errors.

For example `debug`, `release`, `debug-sanitizers-strict` (what CI runs).
Select one with `just preset=<name> build`; `just` then remembers the last
configured preset. The build goes to `.build/<type>[_san]/`.

Options, settable with `-D` or in a preset:

| Option | Default | |
|---|---|---|
| `PX_USE_CCACHE`, `PX_USE_MOLD`, `PX_USE_COMPILE_COMMANDS` | `ON` | Used when found. |
| `PX_ENABLE_ASAN`, `PX_ENABLE_UBSAN` | `OFF` | Set by the sanitizer presets. Libs pass the sanitizer link flag on to whatever links them. |
| `PX_FORCE_ERROR` | `OFF` | Warnings as errors; set by `-strict` presets. |
| `PX_USE_LTO` | `ON` | LTO in Release and RelWithDebInfo, when supported. |
| `PX_DEPS_DIR` | `.deps/` | Where dependency sources live (or `$PX_DEPS_DIR`). |
| `PX_DEPS_BUILD_TYPE` | `Release` | Build type of dependencies. |
| `PX_DIR` | empty | px `framework/` dir to use (or `$PX_DIR`); empty: installed or fetched. |
| `PX_GIT_REPOSITORY`, `PX_GIT_TAG` | px repo, `v0.1.1` | px to fetch when not found. |

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
