# cmake [-D CHECK=ON] [-D CLANG_FORMAT=<bin>] -P <px>/utils/format.cmake
# clang-format over projects/ and tests/; CHECK fails on unformatted files.
#
# Pin, optional, in .clang-format: `# clang-format-version: 21.1.8` (or 21,
# 21.1). Releases format differently, so a mismatch warns; an older major
# fails, as it rejects newer keys.

cmake_minimum_required(VERSION 3.28)

# Run from the project root: script mode sets CMAKE_SOURCE_DIR to the working directory.
set(root "${CMAKE_SOURCE_DIR}")

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

include("${CMAKE_CURRENT_LIST_DIR}/sources.cmake")
__ext_patterns(patterns "${root}/projects;${root}/tests" ${__source_exts} ${__header_exts})
file(GLOB_RECURSE sources ${patterns})
if(NOT sources)
  message(STATUS "nothing to format")
  return()
endif()
list(LENGTH sources count)

if(CHECK)
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
