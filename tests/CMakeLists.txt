# px setups, each a ctest test:
#   cmake -S tests -B .build/tests && ctest --test-dir .build/tests
cmake_minimum_required(VERSION 3.28)
# CXX: only to know the compiler the fixtures get (MSan is Clang only).
project(px_tests CXX)
enable_testing()

set(PX_TEST_PRESET debug CACHE STRING "Template preset template_example_project builds with")
set(PX_TEST_CHECKS -DPX_FORCE_ERRORS=ON CACHE STRING "Configure args template_example_project also gets (checks)")

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
set(common -G Ninja -D CMAKE_BUILD_TYPE=Debug -D PX_FORCE_ERRORS=ON -D PX_USE_COMPILE_COMMANDS=OFF
  -D "PX_DEPS_DIR=${deps_dir}" -D "PX_DIR=${repo}/framework" -D PX_DEPS_LOCK=)

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

# libs_with_deps (shared, static and header-only libs with patched deps) built,
# tested and installed (libs_<variant>), then used from a plain CMake
# project (consume_<variant>):
# - release_lto_asan: Release (LTO) with ASan + UBSan, used from a plain
#   Release build, which has neither: installed archives must hold no LTO
#   objects, and libs must bring the sanitizer runtime. ASan's leak check
#   (LSan) reports leak's bug;
# - multi_config: Ninja Multi-Config, every config built, tested and installed.
foreach(variant release_lto_asan multi_config)
  set(lib libs_${variant})
  set(args "")
  set(consumer_args "")
  set(configs "")
  set(install ${CMAKE_COMMAND} --install ${lib})
  if(variant STREQUAL "release_lto_asan")
    set(args -D CMAKE_BUILD_TYPE=Release -D PX_ENABLE_ASAN=ON -D PX_ENABLE_UBSAN=ON)
    set(consumer_args -D CMAKE_BUILD_TYPE=Release)
  elseif(variant STREQUAL "multi_config")
    set(configs Debug Release)
    # The plain build (default target) builds every config.
    set(args -G "Ninja Multi-Config" "-DCMAKE_CONFIGURATION_TYPES=Debug$<SEMICOLON>Release"
      -D CMAKE_CROSS_CONFIGS=all -D CMAKE_DEFAULT_CONFIGS=all)
    set(install ${CMAKE_COMMAND} --build ${lib} --target install:all)
    set(consumer_args -D CMAKE_BUILD_TYPE=Release)
  endif()
  set(prefix "${CMAKE_CURRENT_BINARY_DIR}/${lib}-install")
  add_fixture(${lib} SOURCE libs_with_deps ARGS -D "CMAKE_INSTALL_PREFIX=${prefix}" ${args})
  set(tests ${lib}_install)
  add_test(NAME ${lib}_install COMMAND ${install})
  if(configs)
    foreach(config IN LISTS configs)
      add_test(NAME ${lib}_test_${config}
        COMMAND ${CMAKE_CTEST_COMMAND} --test-dir ${lib} -C ${config} --output-on-failure)
      list(APPEND tests ${lib}_test_${config})
    endforeach()
    # `just run`'s path file: the default config's exe.
    add_test(NAME ${lib}_run_path COMMAND sh -c "\"$(cat ${lib}/exe/tool)\" && grep -q /Debug/ ${lib}/exe/tool")
    list(APPEND tests ${lib}_run_path)
  else()
    add_test(NAME ${lib}_test COMMAND ${CMAKE_CTEST_COMMAND} --test-dir ${lib} --output-on-failure)
    list(APPEND tests ${lib}_test)
  endif()
  set_tests_properties(${tests} PROPERTIES FIXTURES_REQUIRED ${lib})
  set_tests_properties(${lib}_install PROPERTIES FIXTURES_SETUP ${lib}_installed)

  set(consumer consume_${variant})
  add_fixture(${consumer} SOURCE find_package_consumer AFTER ${lib}_installed
    ARGS -D "CMAKE_PREFIX_PATH=${prefix}" ${consumer_args})
  add_test(NAME ${consumer}_run COMMAND ${consumer}/consumer)
  set_tests_properties(${consumer}_run PROPERTIES FIXTURES_REQUIRED ${consumer})
endforeach()
add_test(NAME libs_release_lto_asan_leak COMMAND libs_release_lto_asan/bin/leak)
set_tests_properties(libs_release_lto_asan_leak PROPERTIES
  FIXTURES_REQUIRED libs_release_lto_asan PASS_REGULAR_EXPRESSION "LeakSanitizer: detected memory leaks")

# Hardening aborts on a buffer overflow (fortify: optimized builds only) and,
# in Debug, on an out-of-bounds index (STL assertions). Through sh: ctest
# fails an aborted process whatever its output.
add_test(NAME libs_multi_config_hardened_fortify COMMAND sh -c "libs_multi_config/bin/Release/hardened fortify 16 || :")
add_test(NAME libs_multi_config_hardened_stl COMMAND sh -c "libs_multi_config/bin/Debug/hardened stl 1 || :")
set_tests_properties(libs_multi_config_hardened_fortify PROPERTIES
  FIXTURES_REQUIRED libs_multi_config PASS_REGULAR_EXPRESSION "buffer overflow detected")
set_tests_properties(libs_multi_config_hardened_stl PROPERTIES
  FIXTURES_REQUIRED libs_multi_config PASS_REGULAR_EXPRESSION "[Aa]ssertion")

# libs_with_deps under a px project (shared deps, prefixed exe), with TSan:
# - deps.lock pins a dep to its commit, not to the one its tag names now
#   (_build static_asserts it), and the configure keeps it (_kept);
# - TSan reports race's bug (_race).
set(lock_dir "${CMAKE_CURRENT_BINARY_DIR}/lock")
set(lock_script "${CMAKE_CURRENT_SOURCE_DIR}/lock.cmake")
add_test(NAME nested_px_tsan_lock_repo COMMAND ${CMAKE_COMMAND} -D MODE=repo -D "DIR=${lock_dir}" -P "${lock_script}")
add_fixture(nested_px_tsan_lock AFTER nested_px_tsan_lock_repo_done ARGS -D PX_ENABLE_TSAN=ON -D "LOCK_REPO=${lock_dir}/repo"
  -D "PX_DEPS_LOCK=${lock_dir}/deps.lock")
add_test(NAME nested_px_tsan_lock_kept COMMAND ${CMAKE_COMMAND} -D MODE=check -D "DIR=${lock_dir}" -P "${lock_script}")
add_test(NAME nested_px_tsan_lock_race COMMAND nested_px_tsan_lock/bin/race)
set_tests_properties(nested_px_tsan_lock_repo PROPERTIES FIXTURES_SETUP nested_px_tsan_lock_repo_done)
set_tests_properties(nested_px_tsan_lock_kept nested_px_tsan_lock_race PROPERTIES FIXTURES_REQUIRED nested_px_tsan_lock)
set_tests_properties(nested_px_tsan_lock_race PROPERTIES PASS_REGULAR_EXPRESSION "ThreadSanitizer: data race")

# MSan reports uninit's bug (Clang only: other compilers must refuse it).
# TSan can't be combined with ASan.
if(CMAKE_CXX_COMPILER_ID STREQUAL "Clang")
  add_fixture(msan_uninit_read ARGS -D PX_ENABLE_MSAN=ON)
  add_test(NAME msan_uninit_read_run COMMAND msan_uninit_read/bin/uninit)
  set_tests_properties(msan_uninit_read_run PROPERTIES
    FIXTURES_REQUIRED msan_uninit_read PASS_REGULAR_EXPRESSION "MemorySanitizer: use-of-uninitialized-value")
else()
  add_test(NAME msan_refused_without_clang
    COMMAND ${CMAKE_COMMAND} --fresh -S "${fixtures}/msan_uninit_read" -B msan_uninit_read ${common} -D PX_ENABLE_MSAN=ON)
  set_tests_properties(msan_refused_without_clang PROPERTIES PASS_REGULAR_EXPRESSION "MSan needs Clang")
endif()
add_test(NAME tsan_with_asan_refused
  COMMAND ${CMAKE_COMMAND} --fresh -S "${fixtures}/msan_uninit_read" -B tsan_with_asan_refused ${common}
    -D PX_ENABLE_TSAN=ON -D PX_ENABLE_ASAN=ON)
set_tests_properties(tsan_with_asan_refused PROPERTIES PASS_REGULAR_EXPRESSION "TSan can't be combined with ASan")

# The installed lib after another fmt version is loaded: configure must stop.
add_test(NAME dep_version_conflict
  COMMAND ${CMAKE_COMMAND} --fresh -S "${fixtures}/dep_version_conflict" -B dep_version_conflict -G Ninja
    -D "CMAKE_PREFIX_PATH=${CMAKE_CURRENT_BINARY_DIR}/libs_release_lto_asan-install"
    -D "fmt_DIR=${fixtures}/dep_version_conflict/fmt")
set_tests_properties(dep_version_conflict PROPERTIES
  FIXTURES_REQUIRED libs_release_lto_asan_installed
  PASS_REGULAR_EXPRESSION "lib was built with fmt 11\\.1\\.4, but fmt 10\\.0\\.0 is already loaded")

# px versions find_package must reject: another major, and in 0.x another minor.
foreach(request 1.0 0.0)
  add_test(NAME px_version_rejected_${request}
    COMMAND ${CMAKE_COMMAND} --fresh -S "${fixtures}/px_version_rejected" -B px_version_rejected_${request}
      -D REQUEST=${request})
  set_tests_properties(px_version_rejected_${request} PROPERTIES
    PASS_REGULAR_EXPRESSION "compatible[ \n]+with requested version \"${request}\"")
endforeach()

# The template plus the fixture's projects/ and tests/, built with the
# template's presets: <name>_{copy,configure,build,test,format}. Deps go to the
# copy's own .deps: the same dep patched differently in a shared deps dir would
# be re-fetched back and forth.
function(add_full_project name)
  set(dir "${CMAKE_CURRENT_BINARY_DIR}/${name}")
  set(steps configure build test)
  add_test(NAME ${name}_copy
    COMMAND ${CMAKE_COMMAND} -D "DEST=${dir}" -D "SOURCES=${repo}/template;${fixtures}/${name}"
      -P "${CMAKE_CURRENT_SOURCE_DIR}/instantiate.cmake")
  add_test(NAME ${name}_configure
    COMMAND ${CMAKE_COMMAND} --fresh --preset ${PX_TEST_PRESET} ${PX_TEST_CHECKS} -D "PX_DIR=${repo}/framework")
  # Each public header must also compile on its own.
  add_test(NAME ${name}_build
    COMMAND ${CMAKE_COMMAND} --build --preset ${PX_TEST_PRESET} --target all all_verify_interface_header_sets)
  add_test(NAME ${name}_test COMMAND ${CMAKE_CTEST_COMMAND} --preset ${PX_TEST_PRESET} --output-on-failure)
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

add_full_project(template_example_project)

# A git repo of this checkout's framework/ and template/, which new.cmake and
# the template's bootstrap fetch px from.
set(px_repo "${CMAKE_CURRENT_BINARY_DIR}/px_repo")
add_test(NAME new_project_px_repo
  COMMAND ${CMAKE_COMMAND} -D "OUT=${px_repo}" -D "REPO=${repo}" -P "${CMAKE_CURRENT_SOURCE_DIR}/px_repo.cmake")
set_tests_properties(new_project_px_repo PROPERTIES FIXTURES_SETUP new_project_px_repo_done)

# new.cmake run in an empty dir, from the local px repo: its latest tag, the
# project named after the dir, and a first configure (no PX_DIR) whose
# bootstrap fetches px at that tag, then a build.
set(new_project_dir "${CMAKE_CURRENT_BINARY_DIR}/newproj")
add_test(NAME new_project_clean
  COMMAND sh -c "\"$0\" -E rm -rf \"$1\" && \"$0\" -E make_directory \"$1\"" ${CMAKE_COMMAND} "${new_project_dir}")
add_test(NAME new_project_create COMMAND ${CMAKE_COMMAND} -D "PX_GIT_REPOSITORY=${px_repo}" -P "${repo}/new.cmake")
# Again, now that the dir isn't empty: refused without FORCE.
add_test(NAME new_project_not_empty COMMAND ${CMAKE_COMMAND} -D "PX_GIT_REPOSITORY=${px_repo}" -P "${repo}/new.cmake")
set_tests_properties(new_project_create new_project_not_empty PROPERTIES WORKING_DIRECTORY "${new_project_dir}")
set_tests_properties(new_project_not_empty PROPERTIES FIXTURES_REQUIRED new_project_created
  PASS_REGULAR_EXPRESSION "isn't empty: -D FORCE=ON")
add_test(NAME new_project_configure
  COMMAND ${CMAKE_COMMAND} --fresh -S "${new_project_dir}" -B "${new_project_dir}/.build" -G Ninja -D "PX_GIT_REPOSITORY=${px_repo}")
set_tests_properties(new_project_clean PROPERTIES FIXTURES_SETUP new_project_cleaned)
set_tests_properties(new_project_create PROPERTIES
  FIXTURES_REQUIRED "new_project_px_repo_done;new_project_cleaned" FIXTURES_SETUP new_project_created)
add_test(NAME new_project_build COMMAND ${CMAKE_COMMAND} --build "${new_project_dir}/.build")
set_tests_properties(new_project_build PROPERTIES FIXTURES_REQUIRED new_project_configured ENVIRONMENT_MODIFICATION PX_DIR=unset:)
set_tests_properties(new_project_configure PROPERTIES
  FIXTURES_REQUIRED new_project_created FIXTURES_SETUP new_project_configured
  ENVIRONMENT_MODIFICATION PX_DIR=unset:
  PASS_REGULAR_EXPRESSION "px +-> ${px_version_regex} \\([^)]*/\\.deps/px-v${px_version_regex}/framework\\)\n[^\n]*Project +-> newproj\n"
  FAIL_REGULAR_EXPRESSION "CMake Error")

# One ccache for all, outside the fixture sources.
get_property(tests DIRECTORY PROPERTY TESTS)
set_tests_properties(${tests} PROPERTIES ENVIRONMENT "CCACHE_DIR=${CMAKE_CURRENT_BINARY_DIR}/ccache")
