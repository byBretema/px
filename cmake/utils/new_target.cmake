# cmake -D NAME=<name> -D TYPE=<EXE|SHARED|STATIC|HEADER_ONLY> -P cmake/utils/new_target.cmake
# Scaffolds projects/<NAME> and adds it to projects/CMakeLists.txt.

cmake_minimum_required(VERSION 3.28)

# Script mode: paths from this file, not the caller's working directory.
cmake_path(GET CMAKE_CURRENT_LIST_DIR PARENT_PATH cmake_dir)
cmake_path(GET cmake_dir PARENT_PATH root)
set(projects "${root}/projects")
set(dir "${projects}/${NAME}")

# Also the libs' C++ namespace.
if(NOT NAME MATCHES "^[A-Za-z_][A-Za-z0-9_]*$")
  message(FATAL_ERROR "invalid name: '${NAME}' (use [A-Za-z_][A-Za-z0-9_]*)")
endif()
if(NOT TYPE MATCHES "^(EXE|SHARED|STATIC|HEADER_ONLY)$")
  message(FATAL_ERROR "invalid type: '${TYPE}' (use EXE, SHARED, STATIC or HEADER_ONLY)")
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
  if(NOT TYPE STREQUAL "HEADER_ONLY")
    file(WRITE "${dir}/${NAME}.cpp" "#include \"${NAME}.hpp\"\n")
  endif()
endif()

set(list_file "${projects}/CMakeLists.txt")
set(entry "add_subdirectory(${NAME})")
set(content "")
if(EXISTS "${list_file}")
  file(READ "${list_file}" content)
endif()
string(REGEX MATCH "(^|\n)add_subdirectory\\(${NAME}\\)(\n|$)" found "${content}")
if(NOT found)
  if(content AND NOT content MATCHES "\n$")
    set(entry "\n${entry}")
  endif()
  file(APPEND "${list_file}" "${entry}\n")
endif()

string(TOLOWER "${TYPE}" kind)
string(REPLACE "_" "-" kind "${kind}")
message(STATUS "created ${kind}: ${NAME} (projects/${NAME})")
