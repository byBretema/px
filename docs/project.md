# Project

## Layout

```
CMakeLists.txt        project name, version, and the px calls (see below)
justfile              shortcuts
CMakePresets.json     build presets
cmake/px.cmake        loads px (below)
cmake/deps.cmake      the third-party dependencies, one block each
cmake/deps.lock       the commit each one resolved to (written by configure)
cmake/patches/        local changes to dependencies
projects/<name>/      one target per directory: an exe or a lib
tests/<name>/         one test per directory
vendor/               third-party code you copy in (on the include path)

.build/  .deps/  .install/  .cache/     generated, git-ignored
```

The root `CMakeLists.txt` is all the top-level CMake a project needs:

```cmake
cmake_minimum_required(VERSION 3.28)
include(cmake/px.cmake)

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

## Loading px

The template loads px through `cmake/px.cmake`, before `project()`, from the
first of:
1. `PX_DIR`: a px `framework/` dir (cache variable, or the `PX_DIR`
   environment variable for both CMake and `just`);
2. an installed px, found by `find_package(px 0.1.2)`;
3. `PX_GIT_TAG` (default `v0.1.2`) of `PX_GIT_REPOSITORY`, fetched once into
   the deps dir as `px-<tag>`. A fetched copy is never updated, so the tag
   must not move: change `PX_GIT_TAG` to upgrade.

A copy kept inside this repo needs `PX_DIR=<repo>/framework`, or it fetches
the tagged px instead of the local one.

px is versioned (`framework/version.cmake`). A request for `0.1` accepts any
`0.1.x`; from 1.0 on, any newer version of the same major. In 0.x a minor
release may break projects.

## Cleaning

```sh
just clean          # builds, installs, ccache, compile_commands.json
just clean deps     # fetched dependency sources
just clean all      # both
```
