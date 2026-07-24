cmake_minimum_required(VERSION 3.28)

project(px  VERSION 0.0.1  DESCRIPTION "Render engine")
include(cmake/Nest.cmake)

add_subdirectory(projects)

Nest_EnableTests()
add_subdirectory(tests)

Nest_GenerateExport()

