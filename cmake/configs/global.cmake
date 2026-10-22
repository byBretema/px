#-------------------------------------------------------------------------------
# Global: settings that must also reach dependencies (included before deps)
#-------------------------------------------------------------------------------

# Static libraries (deps included) are PIC, linkable into shared ones
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# Organized output dirs; dep DLLs land next to executables on Windows.
# A parent project's choice (px used as a subproject) wins.
if(NOT CMAKE_RUNTIME_OUTPUT_DIRECTORY)
  set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin")
  set(CMAKE_LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib")
  set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib")
endif()
