# px

A C++ project template that takes the CMake boilerplate off your hands. You
write code in directories, list the libraries each target uses, and px takes
care of the rest: fetching and patching dependencies, compiler warnings,
sanitizers, ccache and mold, `compile_commands.json`, install rules and
packages. A px project works alone, as a monorepo, or as a subproject of any
CMake project.

```
framework/    px itself
template/     the skeleton a new project starts from
tests/        px's own tests (CI)
docs/         the details
```

## Requirements

- CMake 3.28+, Ninja, git, a C++23 compiler.
- Optional: [just](https://github.com/casey/just), ccache, mold, clang-format.

Linux is the primary platform (CI: Ubuntu 24.04, GCC and Clang); Windows and
macOS are supported.

## Start a project

Copy `template/`, rename the project in its `CMakeLists.txt`, then:

```sh
just add_exe hello      # projects/hello/
just run hello          # configure, build, run
just add_lib util       # projects/util/ (SHARED; or STATIC, HEADER_ONLY)
just test               # build and run tests/
just --list             # everything else
```

`just` only triggers plain CMake: `cmake --preset debug`,
`cmake --build --preset debug`, `ctest --preset debug`.

The first configure fetches px (tag `v0.1.0`) into `.deps/`, unless px is
installed or `PX_DIR` points at a px `framework/` dir. A template copy inside
this repo needs `PX_DIR=<repo>/framework`.

## How it works

```
cmake/deps.cmake      third-party deps, one import_dependency() block each
projects/<name>/      one target per directory, every source in it compiled
tests/<name>/         one test per directory
```

```cmake
# projects/app/CMakeLists.txt
make_exe(app DEPS myproj::util fmt::fmt)

# projects/util/CMakeLists.txt
make_lib(util STATIC DEPS glm::glm PRIVATE_DEPS fmt::fmt)
```

A target sees only the deps it lists. Libraries are linked as
`<project>::<name>`, and export only what is marked `<NAME>_API`.

## Docs

- [Project](docs/project.md): layout, how px is loaded and versioned,
  cleaning.
- [Targets](docs/targets.md): `make_*`, deps, exported symbols, defaults.
- [Dependencies](docs/dependencies.md): `import_dependency`, patches, sources, lock file.
- [Configuration](docs/configuration.md): presets, options, customizing,
  formatting.
- [Install and package](docs/install.md)
- [Subprojects](docs/subprojects.md): monorepo, under another project, px
  inside px.
- [Developing px](docs/developing-px.md): tests, releasing.
- [Changelog](CHANGELOG.md)
