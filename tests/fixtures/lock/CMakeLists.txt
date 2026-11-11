cmake_minimum_required(VERSION 3.28)
# The template's loader; the driver sets PX_DIR, LOCK_REPO and PX_DEPS_LOCK.
include(${CMAKE_CURRENT_LIST_DIR}/../../../template/cmake/px.cmake)

pre_project()
project(lock)
post_project()

add_subdirectory(projects)
