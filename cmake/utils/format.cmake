#-------------------------------------------------------------------------------
# Format: runs clang-format in place over own sources (projects/, tests/)
#
#   cmake -P cmake/utils/format.cmake
#-------------------------------------------------------------------------------

cmake_minimum_required(VERSION 3.28)

# Script mode: paths from this file, not the caller's working directory.
cmake_path(GET CMAKE_CURRENT_LIST_DIR PARENT_PATH cmake_dir)
cmake_path(GET cmake_dir PARENT_PATH root)

# .clang-format uses 21.x keys; older versions reject the whole file.
set(min_version 21)

find_program(clang_format clang-format REQUIRED)
execute_process(COMMAND "${clang_format}" --version OUTPUT_VARIABLE version_out)
string(REGEX MATCH "version ([0-9]+)\\.[0-9.]+" version "${version_out}")
if(CMAKE_MATCH_1 LESS min_version)
  message(FATAL_ERROR "clang-format ${min_version}+ required, found: ${version_out}")
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

execute_process(COMMAND "${clang_format}" -i --style=file ${sources}
  WORKING_DIRECTORY "${root}"
  COMMAND_ERROR_IS_FATAL ANY)

list(LENGTH sources count)
string(REGEX REPLACE "\n$" "" version_out "${version_out}")
message(STATUS "formatted ${count} files (${version_out})")
