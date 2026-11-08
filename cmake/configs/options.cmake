# User options.

option(USE_CCACHE           "Enable ccache build caching" ON  )
option(USE_MOLD             "Use mold linker"             ON  )
option(USE_COMPILE_COMMANDS "Use CompileCommands.json"    ON  )

option(ENABLE_ASAN  "Enable address sanitizer"             OFF)
option(ENABLE_UBSAN "Enable undefined behaviour sanitizer" OFF)

option(FORCE_ERROR "Treat compiler warnings as errors" OFF)


set(DEPS_DIR        "$ENV{DEPS_DIR}" CACHE PATH   "Directory where FetchContent dependencies are stored")
set(DEPS_BUILD_TYPE "Release"        CACHE STRING "Build type for FetchContent dependencies (single-config generators only)")

if(NOT DEPS_DIR)
  set(DEPS_DIR "${CMAKE_SOURCE_DIR}/.deps" CACHE PATH "" FORCE)
endif()


set_property(CACHE DEPS_BUILD_TYPE PROPERTY STRINGS Debug Release RelWithDebInfo MinSizeRel)
