cmake_minimum_required(VERSION 3.28)

include(cmake/base.cmake)

pre_project()
project("px"  VERSION "0.0.1"  DESCRIPTION "A cpp project start point: CMake wrapper to manage deps and opinionated sane-defaults")
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
