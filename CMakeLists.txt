cmake_minimum_required(VERSION 3.28)

set(CMAKE_MESSAGE_LOG_LEVEL "NOTICE")
project(px  VERSION 0.0.1  DESCRIPTION "Render engine")
set(CMAKE_MESSAGE_LOG_LEVEL "STATUS")

include(cmake/ProjectSetup.cmake)

add_subdirectory(projects)

setup_testing()
add_subdirectory(tests)

make_export()

