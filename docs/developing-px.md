# Developing px

## Testing

The test driver (`tests/CMakeLists.txt`) builds these setups, named after
what they check:
- `libs_release_lto_asan`: shared, static and header-only libs with patched
  deps, Release with LTO, ASan and UBSan. Built, tested and installed, then
  used through `find_package` by a plain Release build
  (`consume_release_lto_asan`); its `leak` exe must get an LSan report;
- `libs_multi_config`: the same libs with Ninja Multi-Config, every config
  built, tested and installed, then consumed (`consume_multi_config`);
- `nested_px_tsan_lock`: the libs nested in another px project, with TSan
  (its `race` exe must get a report) and a `deps.lock` that must pin a dep;
- `template_example_project`: the template with example `projects/` and
  `tests/` laid over a copy, built with a template preset, `PX_TEST_PRESET`
  (default `debug`), plus `PX_TEST_CHECKS` (default warnings as errors), and
  format checked;
- `new_project_*`: a project made by `new.cmake` from a local git repo of
  this checkout, whose first configure fetches px at its latest tag, then
  builds.

Configure-only checks: `dep_version_conflict`, `px_version_rejected_*`,
`tsan_with_asan_refused`, and MSan, which Clang must build and report
(`msan_uninit_read`) and other compilers must refuse
(`msan_refused_without_clang`).

From the repo root:

```sh
just test                                  # all
just test template_example_project         # only these
just asan=true ubsan=true test             # template_example_project with other checks
```

Plain CMake: `cmake -S tests -B .build/tests [-D PX_TEST_PRESET=<preset>]
[-D "PX_TEST_CHECKS=-DPX_ENABLE_ASAN=ON;..."]`,
then `ctest --test-dir .build/tests -j 4`.

## Releasing

1. Add the version's section to `CHANGELOG.md` (`## X.Y.Z`).
2. `just publish_tag X.Y.Z`: sets the version in `framework/version.cmake`
   and the template's `cmake/px.cmake` (`__px_version`), commits everything
   as `vX.Y.Z`, tags it and pushes the branch and the tag.
3. CI checks that the tag matches `framework/version.cmake`. Once every job
   passes, it publishes a GitHub Release: the version's CHANGELOG section as
   notes, and `new.cmake` and its wrappers `new.sh`, `new.ps1`, pinned to the
   tag (what the README's one-liners download).
