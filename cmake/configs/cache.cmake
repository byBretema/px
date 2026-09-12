#-------------------------------------------------------------------------------
# Cache: ccache, for building codebase cache
#-------------------------------------------------------------------------------

if(USE_CCACHE)
  find_program(__ccache_found ccache)
  if(__ccache_found)
    log_status("ccache: enabled (${__ccache_found})")
    if(NOT DEFINED ENV{CCACHE_DIR})
      set(ENV{CCACHE_DIR} "${CMAKE_SOURCE_DIR}/.cache/ccache")
    endif()
    file(MAKE_DIRECTORY "$ENV{CCACHE_DIR}")
    set(CMAKE_CXX_COMPILER_LAUNCHER "${__ccache_found}")
    set(CMAKE_C_COMPILER_LAUNCHER "${__ccache_found}")
  else()
    log_status("ccache: not found")
  endif()
endif()
