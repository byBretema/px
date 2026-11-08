# Defaults for own targets (included after deps).

set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

set(CMAKE_CXX_VISIBILITY_PRESET hidden)
set(CMAKE_VISIBILITY_INLINES_HIDDEN ON)

# No CMAKE_DEBUG_POSTFIX: deps build as DEPS_BUILD_TYPE, so names would mismatch.

# Per-config vars: multi-config generators keep Debug without LTO.
if(__multi_config OR CMAKE_BUILD_TYPE MATCHES "^(Release|RelWithDebInfo)$")
  include(CheckIPOSupported)
  check_ipo_supported(RESULT __ipo_supported OUTPUT __ipo_error)
  if(__ipo_supported)
    set(CMAKE_INTERPROCEDURAL_OPTIMIZATION_RELEASE ON)
    set(CMAKE_INTERPROCEDURAL_OPTIMIZATION_RELWITHDEBINFO ON)
  else()
    message(WARNING "IPO/LTO requested but not supported: ${__ipo_error}")
  endif()
endif()

set(CMAKE_CXX_SCAN_FOR_MODULES OFF)

# Also gives header-only libs compile_commands entries (clangd flags).
set(CMAKE_VERIFY_INTERFACE_HEADER_SETS ON)

# Relocatable installs. Windows needs none: DLLs install next to exes.
if(NOT DEFINED CMAKE_INSTALL_RPATH)
  if(APPLE)
    set(__origin "@loader_path")
  else()
    set(__origin "$ORIGIN")
  endif()
  file(RELATIVE_PATH __bin_to_lib "/${CMAKE_INSTALL_BINDIR}" "/${CMAKE_INSTALL_LIBDIR}")
  set(CMAKE_INSTALL_RPATH "${__origin}/${__bin_to_lib}" "${__origin}")
endif()
