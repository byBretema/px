# px

A C++ project template that takes the CMake boilerplate off your hands. You
write code in directories, list the libraries each target uses, and px takes
care of the rest: fetching and patching dependencies, compiler warnings,
sanitizers, ccache and mold, `compile_commands.json`, install rules and
packages.

One repo can hold a single app or a whole monorepo of apps and libraries, and
a px project can also be pulled into another CMake project (px or not) as a
subproject.

## Repository

```
framework/    px itself: the CMake code projects include
template/     the skeleton a new project starts from
tests/        projects checking px setups (CI)
```

To start a project, copy `template/`, rename the project in its
`CMakeLists.txt`, and add targets. `tests/fixtures/full_project_01` is a
worked example: its `projects/` and `tests/` laid over the template.

The template loads px with `find_package(px 0.1 ...)` from `PX_DIR` (cache
variable, or the `PX_DIR` environment variable for both CMake and `just`), by
default `../framework`, so a copy beside `framework/` works as is. Fetching px
by version is planned.

px is versioned (`framework/version.cmake`). A request for `0.1` accepts any
`0.1.x`; from 1.0 on, any newer version of the same major. In 0.x a minor
release may break projects.

Commands below run from the project directory (`template/`).

## Requirements

- CMake 3.28+, Ninja, git, and a C++23 compiler. Some deps need newer ones
  (glaze: GCC 13+, Clang 18+ or MSVC 19.50+), declared with `COMPILERS`.
- Optional: [just](https://github.com/casey/just) (shortcuts below), ccache,
  mold, clang-format.

Linux is the primary platform (CI runs Ubuntu 24.04 with GCC and Clang);
Windows and macOS are supported.

## Quick start

```sh
just build              # configure (first time) and build everything
just test               # build and run all tests
just add_exe hello      # new executable in projects/hello/
just run hello          # build and run one executable
just add_lib util       # new library in projects/util/ (SHARED by default)
```

`just` is only a shortcut. Every command maps to plain CMake:

```sh
cmake --preset debug
cmake --build --preset debug
ctest --preset debug
```

`just --list` shows every recipe; `just list all` also shows the presets.

## Layout

```
CMakeLists.txt        project name, version, and the px calls (see below)
justfile              shortcuts
CMakePresets.json     build presets
cmake/deps.cmake      the third-party dependencies, one block each
cmake/patches/        local changes to dependencies
projects/<name>/      one target per directory: an exe or a lib
tests/<name>/         one test per directory
vendor/               third-party code you copy in (on the include path)

.build/  .deps/  .install/  .cache/     generated, git-ignored
```

The root `CMakeLists.txt` is all the top-level CMake a project needs:

```cmake
cmake_minimum_required(VERSION 3.28)
include(../framework/base.cmake)

pre_project()
project(myproj VERSION 1.0.0)
post_project()

add_subdirectory(projects)
if(PROJECT_IS_TOP_LEVEL)
  setup_testing()
  add_subdirectory(tests)
endif()

setup_export()
```

The project name is also the namespace of your libraries (`myproj::util`) and
the name of the installed package (`find_package(myproj)`).

## Targets

Each directory under `projects/` is one target. Its `CMakeLists.txt` is one
line, and every source file in the directory tree is compiled: there are no
file lists to keep up to date. Code that shouldn't be compiled goes outside the
target directory. A second `CMakeLists.txt` inside a target directory is an
error.

```cmake
make_exe(app DEPS myproj::util fmt::fmt)
make_lib(util STATIC DEPS glm::glm PRIVATE_DEPS fmt::fmt)
make_lib(net SHARED PRIVATE_DEPS asio::asio)
make_lib(math HEADER_ONLY DEPS glm::glm)
make_test(test_util DEPS myproj::util)
```

- `DEPS`: what the target uses. On a library, these are the deps its public
  headers use; consumers of the library get them too.
- `PRIVATE_DEPS` (compiled libs only): deps used only in the library's `.cpp`
  files. Consumers don't see them, and a SHARED lib's private deps don't ship
  in its installed package.
- A target sees only what it lists: no dep reaches a target by accident.
- Link your own libraries as `<project>::<name>` (`myproj::util`), never by
  plain name.
- A compiled library exports only what is marked with `<NAME>_API`, from the
  generated `<name>_export.hpp` (`UTIL_API int add(int, int);`). Symbols are
  hidden by default, and an unmarked function of a SHARED lib can't be linked
  by its users. In a STATIC lib the macro is empty, so switching the type
  needs no code change. `just add_lib` writes the include for you.
- A library's directory is its include root: `projects/util/geo/vec.hpp` is
  included as `#include "geo/vec.hpp"` and installed as
  `include/myproj/util/geo/vec.hpp`.
- New directories must be added to `projects/CMakeLists.txt`
  (`add_subdirectory(<name>)`); `just add_exe` and `just add_lib` do it for
  you.

What every target gets without asking:

- the project's C++ standard (23 by default; `set(PX_CXX_STANDARD 20)` before
  `post_project()` changes it);
- strict warnings (`-Wall -Wextra -Wconversion ...`, `/W4` on MSVC), errors
  with the `*-strict` presets;
- sanitizers with the `*-asan`, `*-ubsan`, `*-sanitizers` presets;
- hidden symbol visibility, PIC, and LTO in Release and RelWithDebInfo;
- a SHARED lib keeps the symbols of static deps it links (such as fmt) to
  itself, so they can't clash with a consumer's own copy.

None of this leaks to dependencies (except ccache, mold, PIC and output dirs)
or to the consumers of your installed libraries (except the C++ standard).

## Dependencies

Dependencies are git repositories, declared once in `cmake/deps.cmake`:

```cmake
import_dependency(fmt::fmt
  GITHUB    fmtlib/fmt          # or GITLAB, BITBUCKET, REPOSITORY <url>
  TAG       11.1.4              # tag, branch or commit
  SUBDIR    include             # include dir, relative to the repo root
  OPTIONS   FMT_TEST=OFF        # the dep's own CMake switches
)
```

Then any target can list `fmt::fmt` in its `DEPS`. Other keywords:

| Keyword | Use |
|---|---|
| `DEFINES` | Preprocessor definitions for targets using the dep (config macros of header-only libs, e.g. `ASIO_STANDALONE`). |
| `PATCH` | A `.patch` file or a CMake script applied after fetching. See [cmake/patches/README.md](cmake/patches/README.md). |
| `BUILD_TYPE` | Build this dep in another configuration (deps build as `Release` by default: `PX_DEPS_BUILD_TYPE`). |
| `COMPILERS` | Minimum compiler versions, e.g. `GNU=13 Clang=18`; checked before fetching. |
| `PACKAGE` | The dep's `find_package` name, when it isn't the namespace (utfcpp's is `utf8cpp`). |
| `INSTALL_HEADERS` | Header-only dep whose own install rules can't be used: px installs its headers instead. |

How sources are handled:

- Sources are fetched once into `.deps/` and shared by every build directory.
  They are fetched again only when the URL, `TAG` or patch changes.
- So one deps dir holds one version of each dep. Projects sharing a deps dir
  (`PX_DEPS_DIR`) must agree on each shared dep's URL, `TAG` and patch: if
  they differ, each configure re-fetches it over the other's. Give such
  projects separate deps dirs.
- Editing a dep in `.deps/<id>-src` to debug it is fine. If a re-fetch would
  throw your edits away, configure stops and prints the commands to save them
  as a patch.
- System libraries that can't be fetched (Qt, Boost): a plain
  `find_package()` in `cmake/deps.cmake`, then link their targets in `DEPS`.

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
| `PX_ENABLE_ASAN`, `PX_ENABLE_UBSAN` | `OFF` | Set by the sanitizer presets. |
| `PX_FORCE_ERROR` | `OFF` | Warnings as errors; set by `-strict` presets. |
| `PX_USE_LTO` | `ON` | LTO in Release and RelWithDebInfo, when supported. |
| `PX_DEPS_DIR` | `.deps/` | Where dependency sources live (or `$PX_DEPS_DIR`). |
| `PX_DEPS_BUILD_TYPE` | `Release` | Build type of dependencies. |
| `PX_DIR` | `../framework` | Where px is (or `$PX_DIR`). |

`compile_commands.json` is copied to the repo root on every build, so clangd
works with no setup.

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

## Install and package

```sh
just preset=release install      # into .install/release/
just preset=release package      # .tar.gz (.zip on Windows) in .build/release/packages/
```

The install tree has your exes, libraries, public headers and a CMake package.
It also contains the dependencies your installed libraries expose, built with
the same patches and options as in your build, and nothing else. Another
project then uses it with:

```cmake
find_package(myproj REQUIRED)    # with CMAKE_PREFIX_PATH pointing at the install tree
target_link_libraries(app PRIVATE myproj::util)
```

- The package finds its bundled deps first, so an older copy elsewhere on the
  consumer's path isn't picked by mistake.
- If the consumer has already loaded another version of a compiled dep (such
  as fmt), configure stops with an error naming both versions, instead of a
  link failure later.
- System packages your installed libraries need are declared with
  `setup_export(DEPS Qt6 ...)`; the package config looks for them again on
  the consumer's side.
- A dependency without usable install rules fails at generate with "requires
  target ... that is not in any export set". The fixes are listed in the
  `import_dependency` docs in `framework/utils/importer.cmake`: turn its install
  option on in `OPTIONS`, use `INSTALL_HEADERS`, or keep it in `PRIVATE_DEPS`
  of a SHARED lib.

Installed executables find px shared libraries next to them
(`$ORIGIN/../lib`), so the tree can be moved anywhere.

## Monorepo or single project

- **Single project**: one directory under `projects/`, or a few (an app plus
  its libraries).
- **Monorepo**: as many apps and libraries under `projects/` as you need, each
  listing only its own deps. Deps are fetched and built once and shared by all
  of them.
- **As a subproject**: any CMake project can `add_subdirectory()` a px
  project and link its libraries (`myproj::util`). In that case px registers
  no tests, install rules or `compile_commands.json`; those belong to the
  top-level project.
- **px inside px**: deps are shared, and the first import of a dependency
  wins, so both projects use the same copy. px itself is loaded once too:
  the child's `find_package(px)` gets the parent's px, and configure stops if
  it isn't a version the child accepts. The child's executables are prefixed
  with its project name (`child_app`) so names don't collide.

## Formatting

```sh
just format         # clang-format over projects/ and tests/
just format_check   # fails on unformatted files (CI)
```

Style lives in `.clang-format`. Its `# clang-format-version: <version>` line
pins the clang-format version, since each release formats slightly
differently. A different version warns, and an older major version fails.
`CLANG_FORMAT=<path>` picks a specific binary.

## Testing px itself

The fixtures in `tests/fixtures/` build px in these setups:
- under a plain CMake parent;
- nested in another px project;
- installed and used through `find_package`;
- with a conflicting dependency version;
- as full projects made from the template (`full_project_*`). These are copied
  into the build dir and built with a template preset, `PX_TEST_PRESET`
  (default `debug-strict`).

From the repo root:

```sh
just test                                  # all
just test full_project_01 nest             # only these
just preset=debug-sanitizers test          # full projects with another preset
```

Plain CMake: `cmake -S tests -B .build/tests [-D PX_TEST_PRESET=<preset>]`,
then `ctest --test-dir .build/tests -j 4`.

## Cleaning

```sh
just clean          # builds, installs, ccache, compile_commands.json
just clean deps     # fetched dependency sources
just clean all      # both
```
