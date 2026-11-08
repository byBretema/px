# User options.

option(PX_USE_CCACHE           "Enable ccache build caching" ON  )
option(PX_USE_MOLD             "Use mold linker"             ON  )
option(PX_USE_COMPILE_COMMANDS "Use CompileCommands.json"    ON  )

option(PX_ENABLE_ASAN  "Enable address sanitizer"             OFF)
option(PX_ENABLE_UBSAN "Enable undefined behaviour sanitizer" OFF)

option(PX_FORCE_ERROR "Treat compiler warnings as errors" OFF)
option(PX_USE_LTO     "LTO in Release and RelWithDebInfo" ON )


set(PX_DEPS_DIR        "$ENV{PX_DEPS_DIR}" CACHE PATH   "Directory where FetchContent dependencies are stored")
set(PX_DEPS_BUILD_TYPE "Release"        CACHE STRING "Build type for FetchContent dependencies (single-config generators only)")

if(NOT PX_DEPS_DIR)
  set(PX_DEPS_DIR "${CMAKE_SOURCE_DIR}/.deps" CACHE PATH "" FORCE)
endif()


set_property(CACHE PX_DEPS_BUILD_TYPE PROPERTY STRINGS Debug Release RelWithDebInfo MinSizeRel)
