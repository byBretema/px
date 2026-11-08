# Settings that also reach deps (included before them).

include(GNUInstallDirs)

# Static deps linkable into shared libs.
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# DLLs next to exes on Windows. A parent project's choice wins.
if(NOT CMAKE_RUNTIME_OUTPUT_DIRECTORY)
  set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin")
  set(CMAKE_LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib")
  set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib")
endif()
