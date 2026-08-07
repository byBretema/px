cmake_minimum_required(VERSION 3.28)

include(cmake/y.cmake)

pre_project()
project(px  VERSION 0.0.1  DESCRIPTION "Render engine")
post_project()

add_subdirectory(projects)

setup_testing()
add_subdirectory(tests)

setup_export()

