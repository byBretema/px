# Project helpers

include_guard(DIRECTORY)
include(${CMAKE_CURRENT_LIST_DIR}/Logger.cmake)

macro(pre_project)
  log_level_to_notice()
endmacro()

macro(post_project)
  log_level_restore()
  log_ln()
  log_status("Compiler for C++ -> ${CMAKE_CXX_COMPILER_ID} ${CMAKE_CXX_COMPILER_VERSION} (${CMAKE_CXX_COMPILER})")
  log_status("Compiler for C   -> ${CMAKE_C_COMPILER_ID} ${CMAKE_C_COMPILER_VERSION} (${CMAKE_C_COMPILER})")
endmacro()
