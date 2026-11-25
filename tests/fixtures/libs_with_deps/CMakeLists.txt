cmake_minimum_required(VERSION 3.28)
# The template's loader; the driver sets PX_DIR.
include(${CMAKE_CURRENT_LIST_DIR}/../../../template/cmake/px.cmake)

pre_project()
project(lib VERSION 1.2.3)
post_project()

add_subdirectory(projects)
if(PROJECT_IS_TOP_LEVEL)
  setup_testing()
  add_subdirectory(tests)
endif()

setup_export()
