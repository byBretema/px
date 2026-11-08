cmake_minimum_required(VERSION 3.28)
find_package(px 0.1 REQUIRED CONFIG PATHS "${CMAKE_CURRENT_LIST_DIR}/../../../framework" NO_DEFAULT_PATH)

pre_project()
project(lib VERSION 1.2.3)
post_project()

add_subdirectory(projects)
if(PROJECT_IS_TOP_LEVEL)
  setup_testing()
  add_subdirectory(tests)
endif()

setup_export()
