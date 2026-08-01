include(GNUInstallDirs)
include_guard(DIRECTORY)

# C++ Standard
set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Build metadata
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# Symbol visibility (smaller/faster binaries)
set(CMAKE_CXX_VISIBILITY_PRESET hidden)
set(CMAKE_VISIBILITY_INLINES_HIDDEN ON)

# Ninja status format
set(ENV{NINJA_STATUS} "[%p] ")

# ---------------------------------------------------------------------------
# ccache — build cache
# ---------------------------------------------------------------------------
option(USE_CCACHE "Enable ccache build caching" ON)
if(USE_CCACHE)
  find_program(__ccache_found ccache)
  if(__ccache_found)
    log_status("ccache: enabled (${__ccache_found})")
    file(MAKE_DIRECTORY "${CMAKE_SOURCE_DIR}/.cache/ccache")
    set(ENV{CCACHE_DIR} "${CMAKE_SOURCE_DIR}/.cache/ccache")
    set(CMAKE_CXX_COMPILER_LAUNCHER "${__ccache_found}")
    set(CMAKE_C_COMPILER_LAUNCHER "${__ccache_found}")
  else()
    log_status("ccache: not found")
  endif()
endif()

# ---------------------------------------------------------------------------
# mold — modern linker (Linux only)
# ---------------------------------------------------------------------------
option(USE_MOLD "Use mold linker" ON)
if(USE_MOLD AND CMAKE_HOST_SYSTEM_NAME STREQUAL "Linux")
  find_program(__mold_found mold)
  if(__mold_found)
    log_status("mold: enabled (${__mold_found})")
    set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -fuse-ld=mold")
    set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} -fuse-ld=mold")
    set(CMAKE_MODULE_LINKER_FLAGS "${CMAKE_MODULE_LINKER_FLAGS} -fuse-ld=mold")
  else()
    log_status("mold: not found")
  endif()
endif()
