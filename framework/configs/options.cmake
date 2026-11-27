# User options.

option(PX_USE_CCACHE           "Enable ccache build caching" ON  )
option(PX_USE_MOLD             "Use mold linker"             ON  )
option(PX_USE_COMPILE_COMMANDS "Use CompileCommands.json"    ON  )

option(PX_ENABLE_ASAN  "Enable address sanitizer"             OFF)
option(PX_ENABLE_UBSAN "Enable undefined behaviour sanitizer" OFF)
option(PX_ENABLE_TSAN  "Enable thread sanitizer"              OFF)
option(PX_ENABLE_MSAN  "Enable memory sanitizer (Clang)"      OFF)
option(PX_ENABLE_LSAN  "Enable leak sanitizer"                OFF)

option(PX_ENABLE_HARDENING      "Abort on memory bugs (fortify, stack protector, ...)" ON )
option(PX_ENABLE_STL_ASSERTIONS "Standard library bounds checks beyond Debug"         OFF)

option(PX_FORCE_ERRORS "Treat compiler warnings as errors" OFF)
option(PX_USE_LTO     "LTO in Release and RelWithDebInfo" ON )


set(PX_DEPS_DIR        "$ENV{PX_DEPS_DIR}" CACHE PATH   "Directory where FetchContent dependencies are stored")
set(PX_DEPS_BUILD_TYPE "Release"        CACHE STRING "Build type for FetchContent dependencies (single-config generators only)")

if(NOT PX_DEPS_DIR)
  set(PX_DEPS_DIR "${CMAKE_SOURCE_DIR}/.deps" CACHE PATH "" FORCE)
endif()


set_property(CACHE PX_DEPS_BUILD_TYPE PROPERTY STRINGS Debug Release RelWithDebInfo MinSizeRel)

# Checks requested (-D, or just's strict=/asan=/...). They stay in the cache
# until set again; sanitizers.cmake rejects bad combinations.
set(__checks "")
foreach(__check ASAN UBSAN TSAN MSAN LSAN)
  if(PX_ENABLE_${__check})
    string(TOLOWER ${__check} __check)
    list(APPEND __checks ${__check})
  endif()
endforeach()
if(NOT __checks)
  set(__checks none)
endif()
list(JOIN __checks ", " __checks)
log_status("Sanitizers       -> ${__checks}")
if(PX_FORCE_ERRORS)
  log_status("Warnings         -> errors (PX_FORCE_ERRORS)")
else()
  log_status("Warnings         -> warnings")
endif()
if(NOT PX_ENABLE_HARDENING)
  log_status("Hardening        -> off")
elseif(PX_ENABLE_STL_ASSERTIONS)
  log_status("Hardening        -> on, STL assertions in every config")
else()
  log_status("Hardening        -> on, STL assertions in Debug")
endif()
