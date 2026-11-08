cmake_minimum_required(VERSION 3.28)
find_package(px 0.1 REQUIRED CONFIG PATHS "${CMAKE_CURRENT_LIST_DIR}/../../../framework" NO_DEFAULT_PATH)

pre_project()
project(nest)
post_project()

add_subdirectory(../lib lib)
add_subdirectory(projects)

if(NOT TARGET lib_tool)
  log_fatal("the nested project's exe should be named lib_tool")
endif()
