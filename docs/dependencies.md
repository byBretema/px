# Dependencies

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
| `PATCH` | A `.patch` file or a CMake script applied after fetching. See [cmake/patches/README.md](../template/cmake/patches/README.md). |
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

## Lock file

Configure writes `cmake/deps.lock`: the commit each dep's URL and `TAG`
resolved to. Commit it. While a dep's URL and `TAG` match its line, every
checkout fetches that commit, so a moved tag or a branch `TAG` doesn't change
the build.

```
fmt::fmt https://github.com/fmtlib/fmt.git@11.1.4 123913715afeb8a437e6388b4473fcc4753e1c9a
```

- Changing a dep's URL or `TAG` resolves it again and rewrites its line;
  removed deps drop out.
- To take a branch's or moved tag's new commit, delete its line (or the file).
- Nested px projects share deps, so only the outermost px project's lock is
  used, and it lists the nested projects' deps too. Under a plain CMake
  parent it is read but never written.
- `-D PX_DEPS_LOCK=<file>` uses another file; `-D PX_DEPS_LOCK=` none.
- Patches aren't in the lock: they are files in the repo already.
