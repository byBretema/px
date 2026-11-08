cmake_minimum_required(VERSION 3.28)
include(../../../framework/base.cmake)

pre_project()
project(lib VERSION 1.2.3)
post_project()

add_subdirectory(projects)
if(PROJECT_IS_TOP_LEVEL)
  setup_testing()
  add_subdirectory(tests)
endif()

setup_export()
