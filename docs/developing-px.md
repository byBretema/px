# Developing px

## Testing

The fixtures in `tests/fixtures/` build px in these setups:
- under a plain CMake parent;
- nested in another px project;
- installed and used through `find_package`, also from a Release build with
  LTO and sanitizers (`lib_release`, `consumer_release`) and with Ninja
  Multi-Config (`lib_multi`, `consumer_multi`);
- with a conflicting dependency version;
- as full projects made from the template (`full_project_*`). These are copied
  into the build dir and built with a template preset, `PX_TEST_PRESET`
  (default `debug-strict`);
- as a bare template outside the repo, fetching px from a local git repo
  (`bootstrap`).

From the repo root:

```sh
just test                                  # all
just test full_project_01 nest             # only these
just preset=debug-sanitizers test          # full projects with another preset
```

Plain CMake: `cmake -S tests -B .build/tests [-D PX_TEST_PRESET=<preset>]`,
then `ctest --test-dir .build/tests -j 4`.

## Releasing

1. Set the version in `framework/version.cmake` and in the template's
   `cmake/px.cmake` (`__px_version`); the tests' configure fails when they
   differ.
2. Add it to `CHANGELOG.md`.
3. Tag the commit `v<version>` and push the tag; CI checks that the tag
   matches `framework/version.cmake`.
