#-------------------------------------------------------------------------------
# Format: runs clang-format over own sources (projects/, tests/)
#
#   cmake -P cmake/utils/format.cmake              format in place
#   cmake -D CHECK=ON -P cmake/utils/format.cmake  fail on unformatted files (CI)
#
# CLANG_FORMAT (-D or env): clang-format binary to use instead of PATH's.
#
# Version pin: project-owned, in the root .clang-format as a comment line
#   # clang-format-version: 21.1.8      (or a prefix: 21, 21.1)
# Each release formats slightly differently, so a mismatch warns; an older
# major fails, since it rejects keys it doesn't know. No pin, no checks.
#-------------------------------------------------------------------------------

cmake_minimum_required(VERSION 3.28)

# Script mode: paths from this file, not the caller's working directory.
cmake_path(GET CMAKE_CURRENT_LIST_DIR PARENT_PATH cmake_dir)
cmake_path(GET cmake_dir PARENT_PATH root)

set(pin "")
if(EXISTS "${root}/.clang-format")
  file(STRINGS "${root}/.clang-format" pin_line REGEX "^# clang-format-version: *[0-9]" LIMIT_COUNT 1)
  string(REGEX MATCH "[0-9][0-9.]*" pin "${pin_line}")
endif()

if(NOT CLANG_FORMAT)
  set(CLANG_FORMAT "$ENV{CLANG_FORMAT}")
endif()
if(CLANG_FORMAT)
  set(clang_format "${CLANG_FORMAT}")
else()
  find_program(clang_format clang-format REQUIRED)
endif()

execute_process(COMMAND "${clang_format}" --version OUTPUT_VARIABLE version_out)
string(REGEX MATCH "version ([0-9]+\\.[0-9.]+)" match "${version_out}")
set(version "${CMAKE_MATCH_1}")
if(NOT match)
  message(FATAL_ERROR "cannot read the clang-format version from: ${version_out}")
endif()
if(pin)
  string(REGEX MATCH "^[0-9]+" pin_major "${pin}")
  string(REGEX MATCH "^[0-9]+" major "${version}")
  string(FIND "${version}." "${pin}." pos)
  set(hint "Get it with `uv tool install clang-format==${pin}.*` (or pipx), or point CLANG_FORMAT at it.")
  if(major LESS pin_major)
    message(FATAL_ERROR "clang-format ${version} is older than the pinned ${pin} (.clang-format). ${hint}")
  elseif(NOT pos EQUAL 0)
    message(WARNING "clang-format ${version} is not the pinned ${pin} (.clang-format): output may differ. ${hint}")
  endif()
endif()

# Not vendor/ or deps: third-party code keeps its own style.
file(GLOB_RECURSE sources
  "${root}/projects/*.cpp" "${root}/projects/*.cc" "${root}/projects/*.c" "${root}/projects/*.cxx"
  "${root}/projects/*.hpp" "${root}/projects/*.hh" "${root}/projects/*.h" "${root}/projects/*.hxx"
  "${root}/tests/*.cpp" "${root}/tests/*.cc" "${root}/tests/*.c" "${root}/tests/*.cxx"
  "${root}/tests/*.hpp" "${root}/tests/*.hh" "${root}/tests/*.h" "${root}/tests/*.hxx")
if(NOT sources)
  message(STATUS "nothing to format")
  return()
endif()
list(LENGTH sources count)

if(CHECK)
  # --Werror: unformatted lines are printed as errors and fail the run.
  execute_process(COMMAND "${clang_format}" --dry-run --Werror --style=file ${sources}
    WORKING_DIRECTORY "${root}"
    RESULT_VARIABLE rc)
  if(NOT rc EQUAL 0)
    message(FATAL_ERROR "unformatted files (above): run `just format`")
  endif()
  message(STATUS "format check passed: ${count} files (clang-format ${version})")
  return()
endif()

execute_process(COMMAND "${clang_format}" -i --style=file ${sources}
  WORKING_DIRECTORY "${root}"
  COMMAND_ERROR_IS_FATAL ANY)
message(STATUS "formatted ${count} files (clang-format ${version})")
