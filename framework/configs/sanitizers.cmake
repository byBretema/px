# Sanitizers: PX_ENABLE_ASAN, PX_ENABLE_UBSAN.

set(__san_flags "")
if(PX_ENABLE_ASAN)
  list(APPEND __san_flags address)
endif()
if(PX_ENABLE_UBSAN)
  list(APPEND __san_flags undefined)
endif()
list(JOIN __san_flags "," __san_flags)

if(MSVC)
  if(PX_ENABLE_UBSAN)
    log_fatal("PX_ENABLE_UBSAN: UBSan is not supported by MSVC, use an ASan-only preset")
  endif()
  # /fsanitize=address rejects CMake's Debug /RTC*. Deps keep theirs (no ASan).
  if(PX_ENABLE_ASAN)
    foreach(lang C CXX)
      string(REGEX REPLACE "/RTC[1csu]*" "" CMAKE_${lang}_FLAGS_DEBUG "${CMAKE_${lang}_FLAGS_DEBUG}")
    endforeach()
  endif()
elseif(__san_flags)
  # Not every toolchain ships the runtimes (MinGW GCC, for one).
  include(CheckCXXSourceCompiles)
  string(MAKE_C_IDENTIFIER "__px_sanitize_${__san_flags}" __san_ok)
  set(CMAKE_REQUIRED_FLAGS "-fsanitize=${__san_flags}")
  set(CMAKE_REQUIRED_QUIET ON)
  check_cxx_source_compiles("int main() { return 0; }" ${__san_ok})
  unset(CMAKE_REQUIRED_FLAGS)
  unset(CMAKE_REQUIRED_QUIET)
  if(NOT ${__san_ok})
    log_fatal("${CMAKE_CXX_COMPILER_ID} ${CMAKE_CXX_COMPILER_VERSION} can't build with -fsanitize=${__san_flags}: "
      "this toolchain has no sanitizer runtime (PX_ENABLE_ASAN/PX_ENABLE_UBSAN)")
  endif()
endif()

function(setup_sanitizers project_name)

  if(NOT __san_flags)
    return()
  endif()

  # link.exe ignores the flag (LNK4044); the compiler pulls in the runtime.
  if(MSVC)
    target_compile_options(${project_name} PRIVATE /fsanitize=${__san_flags})
    return()
  endif()

  target_compile_options(${project_name} PRIVATE -fsanitize=${__san_flags} -fno-omit-frame-pointer)
  # Libs: their objects need the runtime, so whatever links them (a plain
  # parent's exe, an installed lib's consumer) links it too.
  get_target_property(type ${project_name} TYPE)
  set(scope PUBLIC)
  if(type STREQUAL "EXECUTABLE")
    set(scope PRIVATE)
  endif()
  target_link_options(${project_name} ${scope} -fsanitize=${__san_flags})

  # Otherwise UBSan only prints, and tests pass.
  if(PX_ENABLE_UBSAN)
    target_compile_options(${project_name} PRIVATE -fno-sanitize-recover=undefined)
  endif()

endfunction()
