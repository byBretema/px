cmake_minimum_required(VERSION 3.28)

set(PX_DIR "$ENV{PX_DIR}" CACHE PATH "px framework directory")
if(NOT PX_DIR)
  set(PX_DIR "${CMAKE_CURRENT_LIST_DIR}/../framework" CACHE PATH "" FORCE)
endif()
include(${PX_DIR}/base.cmake)

pre_project()
project(myproj VERSION 0.1.0 DESCRIPTION "")
post_project()

log_header("Sub Projects")
add_subdirectory(projects)

# Tests are skipped when used as a subproject.
if(PROJECT_IS_TOP_LEVEL)
  setup_testing()
  add_subdirectory(tests)
endif()

setup_export()

log_header("Done!")
