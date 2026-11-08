cmake_minimum_required(VERSION 3.28)
project(plain CXX)

add_subdirectory(../lib lib)
add_executable(plain ../consumer/main.cpp)
target_link_libraries(plain PRIVATE lib::hdr lib::shl lib::stat)
