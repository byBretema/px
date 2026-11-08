# px setups, each a ctest test:
#   cmake -S tests -B .build/tests && ctest --test-dir .build/tests
cmake_minimum_required(VERSION 3.28)
project(px_tests NONE)
enable_testing()

set(PX_TEST_PRESET debug-strict CACHE STRING "Template preset the full projects build with")

cmake_path(GET CMAKE_CURRENT_SOURCE_DIR PARENT_PATH repo)
set(fixtures "${CMAKE_CURRENT_SOURCE_DIR}/fixtures")
set(deps_dir "${CMAKE_CURRENT_SOURCE_DIR}/.deps")
set(lib_prefix "${CMAKE_CURRENT_BINARY_DIR}/lib-install")
set(common -G Ninja -D CMAKE_BUILD_TYPE=Debug -D PX_FORCE_ERROR=ON -D PX_USE_COMPILE_COMMANDS=OFF
  -D "PX_DEPS_DIR=${deps_dir}")

# <name>_configure and <name>_build tests; the build sets up fixture <name>.
function(add_fixture name)
  cmake_parse_arguments(ARG "" "AFTER" "ARGS" ${ARGN})
  set(bin "${CMAKE_CURRENT_BINARY_DIR}/${name}")
  add_test(NAME ${name}_configure
    COMMAND ${CMAKE_COMMAND} --fresh -S "${fixtures}/${name}" -B "${bin}" ${common} ${ARG_ARGS})
  add_test(NAME ${name}_build COMMAND ${CMAKE_COMMAND} --build "${bin}")
  set_tests_properties(${name}_configure PROPERTIES
    FIXTURES_SETUP ${name}_configured FIXTURES_REQUIRED "${ARG_AFTER}")
  set_tests_properties(${name}_build PROPERTIES
    FIXTURES_SETUP ${name} FIXTURES_REQUIRED ${name}_configured)
endfunction()

# Shared, static and header-only libs with patched deps, built and installed.
add_fixture(lib ARGS -D "CMAKE_INSTALL_PREFIX=${lib_prefix}")
add_test(NAME lib_test COMMAND ${CMAKE_CTEST_COMMAND} --test-dir lib --output-on-failure)
add_test(NAME lib_install COMMAND ${CMAKE_COMMAND} --install lib)
set_tests_properties(lib_test lib_install PROPERTIES FIXTURES_REQUIRED lib)
set_tests_properties(lib_install PROPERTIES FIXTURES_SETUP lib_installed)

# lib under a plain CMake project.
add_fixture(plain)

# lib under a px project: shared deps, prefixed exe.
add_fixture(nest)

# The installed lib from a plain CMake project.
add_fixture(consumer AFTER lib_installed ARGS -D "CMAKE_PREFIX_PATH=${lib_prefix}")
add_test(NAME consumer_run COMMAND consumer/consumer)
set_tests_properties(consumer_run PROPERTIES FIXTURES_REQUIRED consumer)

# The installed lib after another fmt version is loaded: configure must stop.
add_test(NAME conflict
  COMMAND ${CMAKE_COMMAND} --fresh -S "${fixtures}/conflict" -B conflict -G Ninja
    -D "CMAKE_PREFIX_PATH=${lib_prefix}" -D "fmt_DIR=${fixtures}/conflict/fmt")
set_tests_properties(conflict PROPERTIES
  FIXTURES_REQUIRED lib_installed
  PASS_REGULAR_EXPRESSION "lib was built with fmt 11\\.1\\.4, but fmt 10\\.0\\.0 is already loaded")

# The template plus the fixture's projects/ and tests/, built with the
# template's presets: <name>_{copy,configure,build,test,format}. Deps go to the
# copy's own .deps: the same dep patched differently in a shared deps dir would
# be re-fetched back and forth.
function(add_full_project name)
  set(dir "${CMAKE_CURRENT_BINARY_DIR}/${name}")
  add_test(NAME ${name}_copy
    COMMAND ${CMAKE_COMMAND} -D "DEST=${dir}" -D "SOURCES=${repo}/template;${fixtures}/${name}"
      -P "${CMAKE_CURRENT_SOURCE_DIR}/instantiate.cmake")
  add_test(NAME ${name}_configure
    COMMAND ${CMAKE_COMMAND} --fresh --preset ${PX_TEST_PRESET} -D "PX_DIR=${repo}/framework")
  # Each public header must also compile on its own.
  add_test(NAME ${name}_build
    COMMAND ${CMAKE_COMMAND} --build --preset ${PX_TEST_PRESET} --target all all_verify_interface_header_sets)
  add_test(NAME ${name}_test COMMAND ${CMAKE_CTEST_COMMAND} --preset ${PX_TEST_PRESET} --output-on-failure)
  add_test(NAME ${name}_format COMMAND ${CMAKE_COMMAND} -D CHECK=ON -P "${repo}/framework/utils/format.cmake")
  set_tests_properties(${name}_configure ${name}_build ${name}_test ${name}_format PROPERTIES
    WORKING_DIRECTORY "${dir}")

  set(previous ${name}_copy)
  foreach(step configure build test)
    set_tests_properties(${previous} PROPERTIES FIXTURES_SETUP ${previous}_done)
    set_tests_properties(${name}_${step} PROPERTIES FIXTURES_REQUIRED ${previous}_done)
    set(previous ${name}_${step})
  endforeach()
  set_tests_properties(${name}_format PROPERTIES FIXTURES_REQUIRED ${name}_copy_done)
endfunction()

add_full_project(full_project_01)

# One ccache for all, outside the fixture sources.
get_property(tests DIRECTORY PROPERTY TESTS)
set_tests_properties(${tests} PROPERTIES ENVIRONMENT "CCACHE_DIR=${CMAKE_CURRENT_BINARY_DIR}/ccache")
