cmake_minimum_required(VERSION 3.28)

set(CMAKE_MESSAGE_LOG_LEVEL "NOTICE")
project(px  VERSION 0.0.1  DESCRIPTION "Render engine")
set(CMAKE_MESSAGE_LOG_LEVEL "STATUS")

include(cmake/Nest.cmake)

add_subdirectory(projects)

Nest_EnableTests()
add_subdirectory(tests)

Nest_GenerateExport()

