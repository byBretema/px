#-------------------------------------------------------------------------------
# Setup some sane defaults
#-------------------------------------------------------------------------------

# C++ standard
if(NOT DEFINED CMAKE_CXX_STANDARD)
  set(CMAKE_CXX_STANDARD 20)
endif()
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Symbol visibility (smaller/faster binaries)
set(CMAKE_CXX_VISIBILITY_PRESET hidden)
set(CMAKE_VISIBILITY_INLINES_HIDDEN ON)

# Static libraries are PIC, linkable into shared ones
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# Suffix debug libs
set(CMAKE_DEBUG_POSTFIX "-d")

# LTO on optimized builds
if(CMAKE_BUILD_TYPE MATCHES "^(Release|RelWithDebInfo)$")
  set(CMAKE_INTERPROCEDURAL_OPTIMIZATION ON)
endif()

# Set modules flags: -fmodules-ts -fmodule-mapper -fdeps-format
set(CMAKE_CXX_SCAN_FOR_MODULES OFF)

# Export all symbols on Windows DLLs
set(CMAKE_WINDOWS_EXPORT_ALL_SYMBOLS ON)

# Organized output dirs
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin")
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib")
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib")

# Includes
include(GNUInstallDirs)
