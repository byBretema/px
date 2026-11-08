# Monorepo, subprojects, px inside px

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
  the child's `cmake/px.cmake` gets the parent's px, and configure stops if
  it isn't a version the child accepts. The child's executables are prefixed
  with its project name (`child_app`) so names don't collide.
