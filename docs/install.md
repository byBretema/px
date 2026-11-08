# Install and package

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
