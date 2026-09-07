#!/usr/bin/env -S cmake -P
# cmake/stale-check.cmake
#
# Cross-platform staleness check for file(GLOB) sources.
# Compares actual source files against the manifest written during configure.
#
# Usage:
#   cmake -B build
#   cmake -P cmake/stale-check.cmake build
#
# Exit 0 = fresh, exit 1 = stale.

cmake_minimum_required(VERSION 3.28)

if(NOT DEFINED CMAKE_ARGV3 OR CMAKE_ARGV3 STREQUAL "")
  message(FATAL_ERROR "Usage: cmake -P cmake/stale-check.cmake <build_dir>")
endif()

set(build_dir "${CMAKE_ARGV3}")
set(manifest "${build_dir}/glob_manifest.txt")

# --- Find project root (walk up from script dir until CMakeLists.txt) ---
set(_probe "${CMAKE_CURRENT_LIST_DIR}")
while(NOT EXISTS "${_probe}/CMakeLists.txt")
  get_filename_component(_probe "${_probe}" DIRECTORY)
  if(_probe STREQUAL "")
    message(FATAL_ERROR "GLOB_STALE: could not find project root from ${build_dir}")
  endif()
endwhile()
set(CMAKE_SOURCE_DIR "${_probe}")

# --- Check staleness using shared helper ---
include("${CMAKE_SOURCE_DIR}/cmake/utils/manifest.cmake")

if(NOT EXISTS "${manifest}")
  write_manifest("${manifest}")
  message(STATUS "GLOB_MANIFEST: created.")
  return()
endif()

check_manifest("${manifest}" FATAL)
