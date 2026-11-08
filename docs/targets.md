# Targets

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
- hidden symbol visibility, PIC, and LTO in Release and RelWithDebInfo
  (not for STATIC libs: LTO objects in an installed archive only link with
  the same compiler's LTO);
- a SHARED lib keeps the symbols of static deps it links (such as fmt) to
  itself, so they can't clash with a consumer's own copy.

None of this leaks to dependencies (except ccache, mold, PIC and output dirs)
or to the consumers of your installed libraries (except the C++ standard).
