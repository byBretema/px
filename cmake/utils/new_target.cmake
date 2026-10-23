#-------------------------------------------------------------------------------
# New target: scaffolds projects/<NAME> and registers it in projects/CMakeLists.txt
#
#   cmake -D NAME=<name> -D TYPE=<EXE|SHARED|STATIC> -P cmake/utils/new_target.cmake
#-------------------------------------------------------------------------------

cmake_minimum_required(VERSION 3.28)

# Script mode: paths from this file, not the caller's working directory.
cmake_path(GET CMAKE_CURRENT_LIST_DIR PARENT_PATH cmake_dir)
cmake_path(GET cmake_dir PARENT_PATH root)
set(projects "${root}/projects")
set(dir "${projects}/${NAME}")

# The name is also a C++ namespace (libs), so it must be an identifier.
if(NOT NAME MATCHES "^[A-Za-z_][A-Za-z0-9_]*$")
  message(FATAL_ERROR "invalid name: '${NAME}' (use [A-Za-z_][A-Za-z0-9_]*)")
endif()
if(NOT TYPE MATCHES "^(EXE|SHARED|STATIC)$")
  message(FATAL_ERROR "invalid type: '${TYPE}' (use EXE, SHARED or STATIC)")
endif()
if(EXISTS "${dir}")
  message(FATAL_ERROR "already exists: ${dir}")
endif()

if(TYPE STREQUAL "EXE")
  file(WRITE "${dir}/CMakeLists.txt" "make_exe(${NAME})\n")
  file(WRITE "${dir}/main.cpp" "int main() {\n    return 0;\n}\n")
else()
  file(WRITE "${dir}/CMakeLists.txt" "make_lib(${NAME} ${TYPE})\n")
  file(WRITE "${dir}/${NAME}.hpp" "#pragma once\n\nnamespace ${NAME} {\n}\n")
  file(WRITE "${dir}/${NAME}.cpp" "#include \"${NAME}.hpp\"\n")
endif()

set(list_file "${projects}/CMakeLists.txt")
set(entry "add_subdirectory(${NAME})")
set(content "")
if(EXISTS "${list_file}")
  file(READ "${list_file}" content)
endif()
string(REGEX MATCH "(^|\n)add_subdirectory\\(${NAME}\\)(\n|$)" found "${content}")
if(NOT found)
  # Keep the entry on its own line when the file lacks a trailing newline.
  if(content AND NOT content MATCHES "\n$")
    set(entry "\n${entry}")
  endif()
  file(APPEND "${list_file}" "${entry}\n")
endif()

string(TOLOWER "${TYPE}" kind)
message(STATUS "created ${kind}: ${NAME} (projects/${NAME})")
