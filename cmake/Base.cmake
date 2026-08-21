# Project defaults

#-------------------------------------------------------------------------------
# Options
#-------------------------------------------------------------------------------

option(USE_CCACHE           "Enable ccache build caching"          ON )
option(USE_MOLD             "Use mold linker"                      ON )
option(USE_COMPILE_COMMANDS "Use CompileCommands.json"             ON )

option(ENABLE_ASAN          "Enable address sanitizer"             OFF)
option(ENABLE_UBSAN         "Enable undefined behaviour sanitizer" OFF)
option(WARNINGS_AS_ERRORS   "Treat compiler warnings as errors"    OFF)

#-------------------------------------------------------------------------------
# Sane defaults
#-------------------------------------------------------------------------------

# Build type (single-config generators only)
if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE Release CACHE STRING "" FORCE)
endif()

# C++ standard
if(NOT DEFINED CMAKE_CXX_STANDARD)
  set(CMAKE_CXX_STANDARD 20)
endif()
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Symbol visibility (smaller/faster binaries)
set(CMAKE_CXX_VISIBILITY_PRESET hidden)
set(CMAKE_VISIBILITY_INLINES_HIDDEN ON)

# Static libraries are PIC, linkable into shared ones
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# Suffix debug libs
set(CMAKE_DEBUG_POSTFIX "-d")

# LTO on optimized builds
if(CMAKE_BUILD_TYPE MATCHES "^(Release|RelWithDebInfo)$")
  set(CMAKE_INTERPROCEDURAL_OPTIMIZATION ON)
endif()

# Set modules flags: -fmodules-ts -fmodule-mapper -fdeps-format
set(CMAKE_CXX_SCAN_FOR_MODULES OFF)

# Export all symbols on Windows DLLs
set(CMAKE_WINDOWS_EXPORT_ALL_SYMBOLS ON)

# Organized output dirs
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin")
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib")
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib")

# Includes
include(GNUInstallDirs)


#-------------------------------------------------------------------------------
# Cache: ccache, for building codebase cache
#-------------------------------------------------------------------------------

if(USE_CCACHE)
  find_program(__ccache_found ccache)
  if(__ccache_found)
    log_status("ccache: enabled (${__ccache_found})")
    file(MAKE_DIRECTORY "$ENV{CCACHE_DIR}")
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

if(USE_COMPILE_COMMANDS AND NOT DEFINED CMAKE_EXPORT_COMPILE_COMMANDS)
  set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
endif()

if(CMAKE_EXPORT_COMPILE_COMMANDS)
  if(NOT WIN32)
    if(EXISTS "${CMAKE_SOURCE_DIR}/compile_commands.json" AND NOT IS_SYMLINK "${CMAKE_SOURCE_DIR}/compile_commands.json")
      log_warning("Not symlink compile_commands.json found.")
    else()
      file(REMOVE "${CMAKE_SOURCE_DIR}/compile_commands.json")
      file(CREATE_LINK "${CMAKE_BINARY_DIR}/compile_commands.json" "${CMAKE_SOURCE_DIR}/compile_commands.json" SYMBOLIC)
    endif()
  else()
    file(COPY_FILE "${CMAKE_BINARY_DIR}/compile_commands.json" "${CMAKE_SOURCE_DIR}/compile_commands.json" ONLY_IF_DIFFERENT)
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


#-------------------------------------------------------------------------------
# Warnings
#-------------------------------------------------------------------------------

function(setup_warnings project_name)

  # MSVC — compiler conformance flags
  #        (not warnings, but required for correct C++20 behaviour on MSVC)

  set(MSVC_OPTIONS
    /Zc:preprocessor  # conforming preprocessor (two-phase name lookup)
    /utf-8            # source + execution character set = UTF-8
  )

  # MSVC — warning flags (each /wNNNN enables a warning that is
  #        off-by-default at /W4; /weNNNN makes it an error).

  set(MSVC_WARNINGS
    /W4               # warning level 4 (reasonable maximum)
    /permissive-      # strict standards conformance

    /w14242           # C4242 — conversion from 'T1' to 'T2', possible loss of data
    /w14254           # C4254 — 'operator': conversion from 'T1' to 'T2', possible loss of data
    /w14263           # C4263 — member function does not override any base class virtual
    /w14265           # C4265 — class has virtual functions but destructor is not virtual
    /w14287           # C4287 — unsigned/negative constant mismatch
    /we4289           # C4289 — nonstandard extension: loop var used outside for-scope (error)
    /w14296           # C4296 — expression is always 'value'
    /w14311           # C4311 — pointer truncation from 'T1' to 'T2'
    /w14545           # C4545 — expression before comma evaluates to function missing arg list
    /w14546           # C4546 — function call before comma missing argument list
    /w14547           # C4547 — 'op': operator before comma has no effect
    /w14549           # C4549 — 'op1': operator before comma has no effect; did you mean 'op2'?
    /w14555           # C4555 — expression has no effect; expected expression with side-effect
    /w14619           # C4619 — #pragma warning: there is no warning number 'N'
    /w14640           # C4640 — construction of local static object is not thread-safe
    /w14826           # C4826 — conversion from 'T1' to 'T2' is sign-extended
    /w14905           # C4905 — wide string literal cast to 'LPSTR'
    /w14906           # C4906 — string literal cast to 'LPWSTR'
    /w14928           # C4928 — illegal copy-initialisation; more than one implicit conversion
  )

  # Clang and GCC shared flags

  set(COMMON_WARNINGS
    -Wall
    -Wextra
    -Wpedantic
    -Wconversion
    -Wsign-conversion
    -Wshadow
    -Wnon-virtual-dtor
    -Wold-style-cast
    -Wcast-align
    -Wunused
    -Woverloaded-virtual
    -Wnull-dereference
    -Wformat=2
    -Wundef
    -Wdouble-promotion
    -Wimplicit-fallthrough
    -Wno-float-equal
  )

  # Clang only

  set(CLANG_WARNINGS
    ${COMMON_WARNINGS}
    -Wno-c++98-compat
    -Wno-c++98-compat-pedantic
    -Wno-language-extension-token
  )

  # GCC only

  set(GCC_WARNINGS
    ${COMMON_WARNINGS}
    -Wmisleading-indentation
    -Wduplicated-cond
    -Wduplicated-branches
    -Wlogical-op
    -Wuseless-cast
    -Wno-strict-aliasing
  )

  # Enable compiling warnings as errors by default (based on exposed option)

  if(WARNINGS_AS_ERRORS)
    set_target_properties(${project_name} PROPERTIES COMPILE_WARNING_AS_ERROR ON)
  endif()

  # Set the flags

  if(MSVC)
    target_compile_options(${project_name} PUBLIC ${MSVC_OPTIONS} ${MSVC_WARNINGS})
  elseif(CMAKE_CXX_COMPILER_ID MATCHES "Clang")
    target_compile_options(${project_name} PUBLIC ${CLANG_WARNINGS})
  elseif(CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
    target_compile_options(${project_name} PUBLIC ${GCC_WARNINGS})
  endif()

endfunction()

