cmake_minimum_required(VERSION 3.28)
include(../../../framework/base.cmake)

pre_project()
project(nest)
post_project()

add_subdirectory(../lib lib)
add_subdirectory(projects)

if(NOT TARGET lib_tool)
  log_fatal("the nested project's exe should be named lib_tool")
endif()
