cmake_minimum_required(VERSION 3.28)
# MSan's deliberate bug (uninit), and the target of the configures that must
# refuse a sanitizer combination; the driver sets PX_DIR and PX_ENABLE_*SAN.
include(${CMAKE_CURRENT_LIST_DIR}/../../../template/cmake/px.cmake)

pre_project()
project(sanitize)
post_project()

add_subdirectory(projects)
