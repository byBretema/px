# px setups, each a ctest test:
#   cmake -S tests -B .build/tests && ctest --test-dir .build/tests
cmake_minimum_required(VERSION 3.28)
project(px_tests NONE)
enable_testing()

set(PX_TEST_PRESET debug-strict CACHE STRING "Template preset the full projects build with")

cmake_path(GET CMAKE_CURRENT_SOURCE_DIR PARENT_PATH repo)
set(fixtures "${CMAKE_CURRENT_SOURCE_DIR}/fixtures")

# The template's bootstrap fetches tag v<its version>: it must be px's own.
include("${repo}/framework/version.cmake")
file(STRINGS "${repo}/template/cmake/px.cmake" line REGEX "^set\\(__px_version ")
string(REGEX MATCH "[0-9][0-9.]*" template_version "${line}")
if(NOT template_version VERSION_EQUAL PX_VERSION)
  message(FATAL_ERROR "template/cmake/px.cmake has px ${template_version}, framework/version.cmake ${PX_VERSION}: keep them equal")
endif()
string(REPLACE "." "\\." px_version_regex "${PX_VERSION}")
set(deps_dir "${CMAKE_CURRENT_SOURCE_DIR}/.deps")
set(common -G Ninja -D CMAKE_BUILD_TYPE=Debug -D PX_FORCE_ERROR=ON -D PX_USE_COMPILE_COMMANDS=OFF
  -D "PX_DEPS_DIR=${deps_dir}" -D "PX_DIR=${repo}/framework")

# <name>_configure and <name>_build tests of fixtures/<SOURCE> (default
# <name>); the build sets up fixture <name>.
function(add_fixture name)
  cmake_parse_arguments(ARG "" "AFTER;SOURCE" "ARGS" ${ARGN})
  if(NOT ARG_SOURCE)
    set(ARG_SOURCE ${name})
  endif()
  set(bin "${CMAKE_CURRENT_BINARY_DIR}/${name}")
  add_test(NAME ${name}_configure
    COMMAND ${CMAKE_COMMAND} --fresh -S "${fixtures}/${ARG_SOURCE}" -B "${bin}" ${common} ${ARG_ARGS})
  add_test(NAME ${name}_build COMMAND ${CMAKE_COMMAND} --build "${bin}")
  set_tests_properties(${name}_configure PROPERTIES
    FIXTURES_SETUP ${name}_configured FIXTURES_REQUIRED "${ARG_AFTER}")
  set_tests_properties(${name}_build PROPERTIES
    FIXTURES_SETUP ${name} FIXTURES_REQUIRED ${name}_configured)
endfunction()

# Shared, static and header-only libs with patched deps, built, tested and
# installed, then used from a plain CMake project (consumer<variant>):
# - _release: Release (LTO) with ASan + UBSan, used from a plain Release build,
#   which has neither: installed archives must hold no LTO objects, and libs
#   must bring the sanitizer runtime;
# - _multi: Ninja Multi-Config, every config built, tested and installed.
foreach(variant "" _release _multi)
  set(args "")
  set(consumer_args "")
  set(configs "")
  set(install ${CMAKE_COMMAND} --install lib${variant})
  if(variant STREQUAL "_release")
    set(args -D CMAKE_BUILD_TYPE=Release -D PX_ENABLE_ASAN=ON -D PX_ENABLE_UBSAN=ON)
    set(consumer_args -D CMAKE_BUILD_TYPE=Release)
  elseif(variant STREQUAL "_multi")
    set(configs Debug Release)
    # The plain build (default target) builds every config.
    set(args -G "Ninja Multi-Config" "-DCMAKE_CONFIGURATION_TYPES=Debug$<SEMICOLON>Release"
      -D CMAKE_CROSS_CONFIGS=all -D CMAKE_DEFAULT_CONFIGS=all)
    set(install ${CMAKE_COMMAND} --build lib${variant} --target install:all)
    set(consumer_args -D CMAKE_BUILD_TYPE=Release)
  endif()
  set(prefix "${CMAKE_CURRENT_BINARY_DIR}/lib${variant}-install")
  add_fixture(lib${variant} SOURCE lib ARGS -D "CMAKE_INSTALL_PREFIX=${prefix}" ${args})
  set(tests lib${variant}_install)
  add_test(NAME lib${variant}_install COMMAND ${install})
  if(configs)
    foreach(config IN LISTS configs)
      add_test(NAME lib${variant}_test_${config}
        COMMAND ${CMAKE_CTEST_COMMAND} --test-dir lib${variant} -C ${config} --output-on-failure)
      list(APPEND tests lib${variant}_test_${config})
    endforeach()
    # `just run`'s path file: the default config's exe.
    add_test(NAME lib${variant}_run_path COMMAND sh -c "\"$(cat lib${variant}/exe/tool)\" && grep -q /Debug/ lib${variant}/exe/tool")
    list(APPEND tests lib${variant}_run_path)
  else()
    add_test(NAME lib${variant}_test COMMAND ${CMAKE_CTEST_COMMAND} --test-dir lib${variant} --output-on-failure)
    list(APPEND tests lib${variant}_test)
  endif()
  set_tests_properties(${tests} PROPERTIES FIXTURES_REQUIRED lib${variant})
  set_tests_properties(lib${variant}_install PROPERTIES FIXTURES_SETUP lib${variant}_installed)

  add_fixture(consumer${variant} SOURCE consumer AFTER lib${variant}_installed
    ARGS -D "CMAKE_PREFIX_PATH=${prefix}" ${consumer_args})
  add_test(NAME consumer${variant}_run COMMAND consumer${variant}/consumer)
  set_tests_properties(consumer${variant}_run PROPERTIES FIXTURES_REQUIRED consumer${variant})
endforeach()

# lib under a plain CMake project.
add_fixture(plain)

# lib under a px project: shared deps, prefixed exe.
add_fixture(nest)

# The installed lib after another fmt version is loaded: configure must stop.
add_test(NAME conflict
  COMMAND ${CMAKE_COMMAND} --fresh -S "${fixtures}/conflict" -B conflict -G Ninja
    -D "CMAKE_PREFIX_PATH=${CMAKE_CURRENT_BINARY_DIR}/lib-install" -D "fmt_DIR=${fixtures}/conflict/fmt")
set_tests_properties(conflict PROPERTIES
  FIXTURES_REQUIRED lib_installed
  PASS_REGULAR_EXPRESSION "lib was built with fmt 11\\.1\\.4, but fmt 10\\.0\\.0 is already loaded")

# px versions find_package must reject: another major, and in 0.x another minor.
foreach(request 1.0 0.0)
  add_test(NAME px_version_${request}
    COMMAND ${CMAKE_COMMAND} --fresh -S "${fixtures}/px_version" -B px_version_${request} -D REQUEST=${request})
  set_tests_properties(px_version_${request} PROPERTIES
    PASS_REGULAR_EXPRESSION "compatible[ \n]+with requested version \"${request}\"")
endforeach()

# The template plus the fixture's projects/ and tests/ (none with BARE, which
# also has no _test: the presets fail on no tests), built with the template's
# presets: <name>_{copy,configure,build,test,format}. ARGS
# replace the configure's default PX_DIR. Deps go to the copy's own .deps: the
# same dep patched differently in a shared deps dir would be re-fetched back
# and forth.
function(add_full_project name)
  cmake_parse_arguments(ARG "BARE" "" "ARGS" ${ARGN})
  set(dir "${CMAKE_CURRENT_BINARY_DIR}/${name}")
  set(sources "${repo}/template")
  set(targets all)
  set(steps configure build)
  if(NOT ARG_BARE)
    list(APPEND steps test)
    list(APPEND sources "${fixtures}/${name}")
    # Each public header must also compile on its own (no header sets in a bare one).
    list(APPEND targets all_verify_interface_header_sets)
  endif()
  if(NOT ARG_ARGS)
    set(ARG_ARGS -D "PX_DIR=${repo}/framework")
  endif()
  add_test(NAME ${name}_copy
    COMMAND ${CMAKE_COMMAND} -D "DEST=${dir}" -D "SOURCES=${sources}"
      -P "${CMAKE_CURRENT_SOURCE_DIR}/instantiate.cmake")
  add_test(NAME ${name}_configure
    COMMAND ${CMAKE_COMMAND} --fresh --preset ${PX_TEST_PRESET} ${ARG_ARGS})
  add_test(NAME ${name}_build COMMAND ${CMAKE_COMMAND} --build --preset ${PX_TEST_PRESET} --target ${targets})
  if(NOT ARG_BARE)
    add_test(NAME ${name}_test COMMAND ${CMAKE_CTEST_COMMAND} --preset ${PX_TEST_PRESET} --output-on-failure)
  endif()
  add_test(NAME ${name}_format COMMAND ${CMAKE_COMMAND} -D CHECK=ON -P "${repo}/framework/utils/format.cmake")
  list(TRANSFORM steps PREPEND ${name}_ OUTPUT_VARIABLE step_tests)
  set_tests_properties(${step_tests} ${name}_format PROPERTIES WORKING_DIRECTORY "${dir}")

  set(previous ${name}_copy)
  foreach(step IN LISTS steps)
    set_tests_properties(${previous} PROPERTIES FIXTURES_SETUP ${previous}_done)
    set_tests_properties(${name}_${step} PROPERTIES FIXTURES_REQUIRED ${previous}_done)
    set(previous ${name}_${step})
  endforeach()
  set_tests_properties(${name}_format PROPERTIES FIXTURES_REQUIRED ${name}_copy_done)
endfunction()

add_full_project(full_project_01)

# The bare template with no PX_DIR: its bootstrap fetches px from a git repo
# of this checkout's framework/.
set(px_repo "${CMAKE_CURRENT_BINARY_DIR}/px_repo")
add_test(NAME bootstrap_repo
  COMMAND ${CMAKE_COMMAND} -D "OUT=${px_repo}" -D "REPO=${repo}"
    -D "FETCHED=${CMAKE_CURRENT_BINARY_DIR}/bootstrap/.deps/px-HEAD" -P "${CMAKE_CURRENT_SOURCE_DIR}/bootstrap.cmake")
add_full_project(bootstrap BARE ARGS -D "PX_GIT_REPOSITORY=${px_repo}" -D PX_GIT_TAG=HEAD)
set_tests_properties(bootstrap_repo PROPERTIES FIXTURES_SETUP bootstrap_repo_done)
set_tests_properties(bootstrap_configure PROPERTIES
  FIXTURES_REQUIRED "bootstrap_copy_done;bootstrap_repo_done"
  ENVIRONMENT_MODIFICATION PX_DIR=unset:
  PASS_REGULAR_EXPRESSION "px +-> ${px_version_regex} \\([^)]*/\\.deps/px-HEAD/framework\\)"
  FAIL_REGULAR_EXPRESSION "CMake Error")

# One ccache for all, outside the fixture sources.
get_property(tests DIRECTORY PROPERTY TESTS)
set_tests_properties(${tests} PROPERTIES ENVIRONMENT "CCACHE_DIR=${CMAKE_CURRENT_BINARY_DIR}/ccache")
