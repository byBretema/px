# ccache (PX_USE_CCACHE).

if(PX_USE_CCACHE)
  find_program(__ccache_found ccache)
  if(__ccache_found)
    set(__ccache_dir "$ENV{CCACHE_DIR}")
    if(NOT __ccache_dir)
      set(__ccache_dir "${CMAKE_SOURCE_DIR}/.cache/ccache")
    endif()
    log_status("ccache: enabled (${__ccache_found}, cache_dir=${__ccache_dir})")
    file(MAKE_DIRECTORY "${__ccache_dir}")
    # On the command line: ENV{} set here doesn't reach the build.
    set(CMAKE_CXX_COMPILER_LAUNCHER "${__ccache_found}" "cache_dir=${__ccache_dir}")
    set(CMAKE_C_COMPILER_LAUNCHER "${__ccache_found}" "cache_dir=${__ccache_dir}")
  else()
    log_status("ccache: not found")
  endif()
endif()
