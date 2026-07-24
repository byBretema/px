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
option(NEST_CCACHE "Enable ccache build caching" ON)
if(NEST_CCACHE)
  find_program(__nest_g_CCACHE ccache)
  if(__nest_g_CCACHE)
    message(STATUS "ccache: enabled (${__nest_g_CCACHE})")
    file(MAKE_DIRECTORY "${CMAKE_SOURCE_DIR}/.cache/ccache")
    set(ENV{CCACHE_DIR} "${CMAKE_SOURCE_DIR}/.cache/ccache")
    set(CMAKE_CXX_COMPILER_LAUNCHER "${__nest_g_CCACHE}")
    set(CMAKE_C_COMPILER_LAUNCHER "${__nest_g_CCACHE}")
  else()
    message(STATUS "ccache: not found")
  endif()
endif()

# ---------------------------------------------------------------------------
# mold — modern linker (Linux only)
# ---------------------------------------------------------------------------
option(NEST_MOLD "Use mold linker" ON)
if(NEST_MOLD AND CMAKE_HOST_SYSTEM_NAME STREQUAL "Linux")
  find_program(__nest_g_MOLD mold)
  if(__nest_g_MOLD)
    message(STATUS "mold: enabled (${__nest_g_MOLD})")
    set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -fuse-ld=mold")
    set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} -fuse-ld=mold")
    set(CMAKE_MODULE_LINKER_FLAGS "${CMAKE_MODULE_LINKER_FLAGS} -fuse-ld=mold")
  else()
    message(STATUS "mold: not found")
  endif()
endif()
