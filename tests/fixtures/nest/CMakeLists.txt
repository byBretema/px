cmake_minimum_required(VERSION 3.28)
# The template's loader; the driver sets PX_DIR.
include(${CMAKE_CURRENT_LIST_DIR}/../../../template/cmake/px.cmake)

pre_project()
project(nest)
post_project()

add_subdirectory(../lib lib)
add_subdirectory(projects)

if(NOT TARGET lib_tool)
  log_fatal("the nested project's exe should be named lib_tool")
endif()
