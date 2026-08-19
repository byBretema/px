# Project defaults

#-------------------------------------------------------------------------------
# Options
#-------------------------------------------------------------------------------

option(USE_CCACHE           "Enable ccache build caching"          ON )
option(USE_MOLD             "Use mold linker"                      ON )
option(USE_COMPILE_COMMANDS "Use CompileCommands.json"             ON )
option(ENABLE_ASAN          "Enable address sanitizer"             OFF)
option(ENABLE_UBSAN         "Enable undefined behaviour sanitizer" OFF)
option(CPP_STANDARND        "Cpp Standard"                         20 )


#-------------------------------------------------------------------------------
# Environment
#-------------------------------------------------------------------------------

set(ENV{NINJA_STATUS} "[%p] ")  # Ninja status format


#-------------------------------------------------------------------------------
# Sane defaults
#-------------------------------------------------------------------------------

# C++ Standard
set(CMAKE_CXX_STANDARD ${CPP_STANDARD})
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Symbol visibility (smaller/faster binaries)
set(CMAKE_CXX_VISIBILITY_PRESET hidden)
set(CMAKE_VISIBILITY_INLINES_HIDDEN ON)

# Set modules flags: -fmodules-ts -fmodule-mapper -fdeps-format
set(CMAKE_CXX_SCAN_FOR_MODULES OFF)

# Includes
include(GNUInstallDirs)


#-------------------------------------------------------------------------------
# Cache: ccache, for build cache
#-------------------------------------------------------------------------------

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


#-------------------------------------------------------------------------------
# Linker: mold, replacement for ld/gold/lld (Linux only)
#-------------------------------------------------------------------------------

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


#-------------------------------------------------------------------------------
# Compile Commands
#-------------------------------------------------------------------------------

if(USE_COMPILE_COMMANDS)
  set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

  if(NOT WIN32)
    if(EXISTS "${CMAKE_SOURCE_DIR}/compile_commands.json" AND NOT IS_SYMLINK "${CMAKE_SOURCE_DIR}/compile_commands.json")
      log_warning("compile_commands.json exists and is not a symlink — leaving it alone")
    else()
      file(REMOVE "${CMAKE_SOURCE_DIR}/compile_commands.json")
      file(CREATE_LINK "${CMAKE_BINARY_DIR}/compile_commands.json"
                       "${CMAKE_SOURCE_DIR}/compile_commands.json"
                       SYMBOLIC)
    endif()
  else()
    file(COPY_FILE "${CMAKE_BINARY_DIR}/compile_commands.json"
                   "${CMAKE_SOURCE_DIR}/compile_commands.json"
                   ONLY_IF_DIFFERENT)
  endif()
endif()


#-------------------------------------------------------------------------------
# Sanitizers
#-------------------------------------------------------------------------------

function(setup_sanitizers project_name)
  set(san_flags "")
  if(ENABLE_ASAN)
    list(APPEND san_flags -fsanitize=address)
  endif()
  if(ENABLE_UBSAN)
    list(APPEND san_flags -fsanitize=undefined)
  endif()
  if(san_flags)
    string(REPLACE ";" "," san_flags "${san_flags}")
    target_compile_options(${project_name} PRIVATE -fsanitize=${san_flags})
    target_link_options(${project_name} PRIVATE -fsanitize=${san_flags})
  endif()
endfunction()

