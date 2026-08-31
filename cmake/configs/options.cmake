#-------------------------------------------------------------------------------
# User options / vars
#-------------------------------------------------------------------------------

# Options: Use

option(USE_CCACHE           "Enable ccache build caching" ON  )
option(USE_MOLD             "Use mold linker"             ON  )
option(USE_COMPILE_COMMANDS "Use CompileCommands.json"    ON  )

# NOTE: Usually better for very fragmented memory, bad for large chunks of memory
option(USE_MIMALLOC         "Use mimalloc allocator"      OFF )

# Options: Enable

option(ENABLE_ASAN  "Enable address sanitizer"             OFF)
option(ENABLE_UBSAN "Enable undefined behaviour sanitizer" OFF)

# Options: Force

option(FORCE_ERROR "Treat compiler warnings as errors" OFF)
option(DEPS_FORCE_OPTIMIZATION "Compile FetchContent dependencies with maximum optimization" ON)


# Vars

set(DEPS_DIR        "$ENV{DEPS_DIR}" CACHE PATH   "Directory where FetchContent dependencies are stored")
set(DEPS_BUILD_TYPE "Release"        CACHE STRING "Build type for FetchContent dependencies"            )

if(NOT DEPS_DIR)
  set(DEPS_DIR "${CMAKE_BINARY_DIR}/.deps" CACHE PATH "" FORCE)
endif()


# UI

set_property(CACHE DEPS_BUILD_TYPE PROPERTY STRINGS Debug Release RelWithDebInfo MinSizeRel)
