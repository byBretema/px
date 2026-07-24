cmake_minimum_required(VERSION 3.28)

project(px
  VERSION 0.1.0
  DESCRIPTION "A curated, lightweight, modern C++ project"
  LANGUAGES CXX C
)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

include(cmake/Warnings.cmake)
include(cmake/Sanitizers.cmake)
include(cmake/Nest.cmake)
include(cmake/Dependencies.cmake)

add_subdirectory(projects)
add_subdirectory(tests)

include(cmake/CompileCommands.cmake)
