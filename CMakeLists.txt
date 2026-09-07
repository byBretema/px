cmake_minimum_required(VERSION 3.28)

include(cmake/base.cmake)

# set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

pre_project()
project("px"  VERSION "0.0.1"  DESCRIPTION "Render engine")
post_project()

log_header("Sub Projects")
add_subdirectory(projects)

setup_testing()
add_subdirectory(tests)

setup_export()

# --- Glob staleness check ---
set(_manifest "${CMAKE_BINARY_DIR}/glob_manifest.txt")
check_manifest("${_manifest}")
write_manifest("${_manifest}")

log_header("Done!")
