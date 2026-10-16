# Dependency patches

Local modifications to third-party dependencies fetched by `import_dependency()`
(`cmake/deps.cmake`). One file per dependency, hooked up with the `PATCH`
argument:

```cmake
import_dependency(fmt::fmt
  GITHUB    fmtlib/fmt
  TAG       11.1.4
  SUBDIR    include
  PATCH     ${CMAKE_CURRENT_LIST_DIR}/patches/fmt.patch
)
```

## Formats

- `<name>.patch` / `<name>.diff`: a git diff, applied with `git apply` at the
  root of the dependency's checkout. Preferred for source changes.
- `<name>.cmake`: a CMake script, `include()`d with `${<fetch_id>_SOURCE_DIR}`
  pointing at the checkout (`fetch_id` is the lowercased `org_repo`, e.g.
  `nemtrif_utfcpp`). Use it for changes a diff expresses badly, such as
  generated or appended content.

## Lifecycle

- A patch runs once, right after a fresh fetch of the dependency into
  `.deps/<fetch_id>-src`, never on cached sources.
- The patch file's SHA1 is part of the dependency's stamp
  (`.deps/<fetch_id>.stamp`), so editing it re-fetches and re-patches on the
  next configure.
- The fetched upstream commit is tagged `px-base`; the patch result is committed
  on top of it, so a patched checkout counts as clean.
- A failing patch stops configure and leaves the previous source untouched.

## Turning local edits into a patch

Edit the checkout in `.deps/<fetch_id>-src` directly, then capture the full
diff from upstream (it includes any patch already applied, so it replaces it):

```sh
git -C .deps/<fetch_id>-src add -A
git -C .deps/<fetch_id>-src diff --cached --binary px-base > cmake/patches/<name>.patch
```

Point the dependency's `PATCH` at the new file (dropping any previous one) and
reconfigure. Configure prints these same commands when a re-fetch would
otherwise discard local edits.

## Current files

`utfcpp.cmake` and `argparse.patch` are a test playground covering both formats:
each adds a `PX_PATCHED_<NAME>` define, and `tests/test_patch` fails to compile
without them.
