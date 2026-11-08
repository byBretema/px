cmake_minimum_required(VERSION 3.28)
project(consumer CXX)

find_package(lib REQUIRED)
add_executable(consumer main.cpp)
target_link_libraries(consumer PRIVATE lib::hdr lib::shl lib::stat)
