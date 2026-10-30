#-------------------------------------------------------------------------------
# Setup some sane defaults
#-------------------------------------------------------------------------------

# C++ standard: a compile feature on every own target (make_*), so installed
# libs carry it to consumers. CMAKE_CXX_STANDARD can raise it, not lower it.
set(__cxx_std cxx_std_23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Symbol visibility (smaller/faster binaries)
set(CMAKE_CXX_VISIBILITY_PRESET hidden)
set(CMAKE_VISIBILITY_INLINES_HIDDEN ON)

# NOTE: CMAKE_DEBUG_POSTFIX is intentionally omitted. It conflicts with
# DEPS_BUILD_TYPE forcing different build types per dependency — in single-config
# generators the consuming target resolves library paths using the global
# CMAKE_BUILD_TYPE + CMAKE_DEBUG_POSTFIX, producing mismatched filenames when
# deps are built as Release while the project is Debug.

# LTO on optimized builds. Per-config variables, so multi-config generators
# don't get LTO in Debug.
if(__multi_config OR CMAKE_BUILD_TYPE MATCHES "^(Release|RelWithDebInfo)$")
  include(CheckIPOSupported)
  check_ipo_supported(RESULT _ipo_supported OUTPUT _ipo_error)
  if(_ipo_supported)
    set(CMAKE_INTERPROCEDURAL_OPTIMIZATION_RELEASE ON)
    set(CMAKE_INTERPROCEDURAL_OPTIMIZATION_RELWITHDEBINFO ON)
  else()
    message(WARNING "IPO/LTO requested but not supported: ${_ipo_error}")
  endif()
endif()

# No C++20 module scanning: px uses no modules, and scanning costs a
# dependency pass per source.
set(CMAKE_CXX_SCAN_FOR_MODULES OFF)

# One TU per public header (`all_verify_interface_header_sets` target): checks
# headers are self-contained, and gives header-only libs compile_commands
# entries, so clangd parses them with the lib's flags (C++23), not guessed ones.
set(CMAKE_VERIFY_INTERFACE_HEADER_SETS ON)

# Includes
include(GNUInstallDirs)
