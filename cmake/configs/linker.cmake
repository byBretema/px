#-------------------------------------------------------------------------------
# Linker: mold, replacement for ld/gold/lld (ELF only)
#-------------------------------------------------------------------------------

# Probed rather than assumed: GCC < 12.1 rejects -fuse-ld=mold, and mold
# cannot link Mach-O/PE (the probe fails there). CMAKE_LINKER_TYPE (3.29+)
# would replace this.
if(USE_MOLD AND NOT MSVC)
  find_program(__mold_found mold)
  if(__mold_found)
    include(CheckLinkerFlag)
    set(CMAKE_REQUIRED_QUIET ON)
    check_linker_flag(CXX "-fuse-ld=mold" __mold_supported)
    unset(CMAKE_REQUIRED_QUIET)
  endif()
  if(__mold_supported)
    log_status("mold: enabled (${__mold_found})")
    set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -fuse-ld=mold")
    set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} -fuse-ld=mold")
    set(CMAKE_MODULE_LINKER_FLAGS "${CMAKE_MODULE_LINKER_FLAGS} -fuse-ld=mold")
  elseif(__mold_found)
    log_status("mold: not supported by ${CMAKE_CXX_COMPILER_ID} ${CMAKE_CXX_COMPILER_VERSION}")
  else()
    log_status("mold: not found")
  endif()
endif()
