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

# NOTE: CMAKE_DEBUG_POSTFIX is intentionally omitted. It conflicts with
# DEPS_BUILD_TYPE forcing different build types per dependency — in single-config
# generators the consuming target resolves library paths using the global
# CMAKE_BUILD_TYPE + CMAKE_DEBUG_POSTFIX, producing mismatched filenames when
# deps are built as Release while the project is Debug.

# LTO on optimized builds
if(CMAKE_BUILD_TYPE MATCHES "^(Release|RelWithDebInfo)$")
  include(CheckIPOSupported)
  check_ipo_supported(RESULT _ipo_supported OUTPUT _ipo_error)
  if(_ipo_supported)
    set(CMAKE_INTERPROCEDURAL_OPTIMIZATION ON)
  else()
    message(WARNING "IPO/LTO requested but not supported: ${_ipo_error}")
  endif()
endif()

# Set modules flags: -fmodules-ts -fmodule-mapper -fdeps-format
set(CMAKE_CXX_SCAN_FOR_MODULES OFF)

# Organized output dirs
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin")
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib")
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib")

# Includes
include(GNUInstallDirs)
