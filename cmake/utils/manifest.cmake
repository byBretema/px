#-------------------------------------------------------------------------------
# Glob manifest — tracks source files for staleness detection.
#
# scan_source_files(out_var)
#   Scans projects/ and tests/ for source and header files.
#   Sets ${out_var} to a sorted list of absolute paths.
#
# write_manifest(path)
#   Writes a manifest file from the current scan results.
#
# read_manifest(path out_var)
#   Reads a manifest file into a list variable.
#
# check_manifest(path [FATAL])
#   Compares current source tree against manifest.
#   With FATAL: exits on staleness. Without: warns only.
#-------------------------------------------------------------------------------

include_guard(DIRECTORY)
include(${CMAKE_CURRENT_LIST_DIR}/logger.cmake)

function(scan_source_files out_var)
  set(_files "")
  foreach(dir projects tests)
    set(_full "${CMAKE_SOURCE_DIR}/${dir}")
    if(NOT IS_DIRECTORY "${_full}")
      continue()
    endif()
    file(GLOB_RECURSE _hits
      "${_full}/*.cpp" "${_full}/*.cc" "${_full}/*.c" "${_full}/*.cxx"
      "${_full}/*.hpp" "${_full}/*.hh" "${_full}/*.h"  "${_full}/*.hxx")
    foreach(_f IN LISTS _hits)
      file(REAL_PATH "${_f}" _resolved)
      list(APPEND _files "${_resolved}")
    endforeach()
  endforeach()
  list(SORT _files)
  set(${out_var} "${_files}" PARENT_SCOPE)
endfunction()


function(write_manifest path)
  scan_source_files(_files)
  file(WRITE "${path}" "")
  foreach(_f IN LISTS _files)
    file(APPEND "${path}" "${_f}\n")
  endforeach()
endfunction()


function(read_manifest path out_var)
  if(NOT EXISTS "${path}")
    set(${out_var} "" PARENT_SCOPE)
    return()
  endif()
  file(READ "${path}" _raw)
  string(REGEX REPLACE "\r?\n" ";" _list "${_raw}")
  list(REMOVE_ITEM _list "")
  set(${out_var} "${_list}" PARENT_SCOPE)
endfunction()


function(check_manifest path)
  cmake_parse_arguments(ARG "FATAL" "" "" ${ARGN})

  if(NOT EXISTS "${path}")
    return()
  endif()

  scan_source_files(_current)
  read_manifest("${path}" _previous)

  if("${_current}" STREQUAL "${_previous}")
    log_status("GLOB_FRESH: source tree is up to date.")
    return()
  endif()

  set(_added "")
  set(_removed "")
  foreach(_f IN LISTS _current)
    if(NOT "${_f}" IN_LIST _previous)
      list(APPEND _added "${_f}")
    endif()
  endforeach()
  foreach(_f IN LISTS _previous)
    if(NOT "${_f}" IN_LIST _current)
      list(APPEND _removed "${_f}")
    endif()
  endforeach()

  if(_added)
    foreach(_f IN LISTS _added)
      log_warning("GLOB_STALE: + ${_f}")
    endforeach()
  endif()
  if(_removed)
    foreach(_f IN LISTS _removed)
      log_warning("GLOB_STALE: - ${_f}")
    endforeach()
  endif()

  if(ARG_FATAL)
    log_fatal("GLOB_STALE: source tree changed. Re-run cmake configure.")
  else()
    log_warning("GLOB_STALE: source tree changed. CI will fail if this persists.")
  endif()
endfunction()
