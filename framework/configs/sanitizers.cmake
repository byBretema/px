# Sanitizers: PX_ENABLE_ASAN, PX_ENABLE_UBSAN, PX_ENABLE_TSAN, PX_ENABLE_MSAN,
# PX_ENABLE_LSAN. Only own targets are instrumented: deps, and so races or
# uninitialized memory inside them, are not (MSan reports false positives
# for whatever uninstrumented code initializes).

set(__san_flags "")
foreach(__san ASAN=address UBSAN=undefined TSAN=thread MSAN=memory LSAN=leak)
  string(REPLACE "=" ";" __san "${__san}")
  list(GET __san 0 __san_option)
  list(GET __san 1 __san_flag)
  if(PX_ENABLE_${__san_option})
    list(APPEND __san_flags ${__san_flag})
  endif()
endforeach()
list(JOIN __san_flags "," __san_flags)

if(PX_ENABLE_TSAN AND (PX_ENABLE_ASAN OR PX_ENABLE_MSAN OR PX_ENABLE_LSAN))
  log_fatal("PX_ENABLE_TSAN: TSan can't be combined with ASan, MSan or LSan")
endif()
if(PX_ENABLE_MSAN AND (PX_ENABLE_ASAN OR PX_ENABLE_LSAN))
  log_fatal("PX_ENABLE_MSAN: MSan can't be combined with ASan or LSan")
endif()

if(MSVC)
  if(PX_ENABLE_UBSAN OR PX_ENABLE_TSAN OR PX_ENABLE_MSAN OR PX_ENABLE_LSAN)
    log_fatal("MSVC only has ASan (PX_ENABLE_ASAN): use an ASan-only preset")
  endif()
  # /fsanitize=address rejects CMake's Debug /RTC*. Deps keep theirs (no ASan).
  if(PX_ENABLE_ASAN)
    foreach(lang C CXX)
      string(REGEX REPLACE "/RTC[1csu]*" "" CMAKE_${lang}_FLAGS_DEBUG "${CMAKE_${lang}_FLAGS_DEBUG}")
    endforeach()
  endif()
elseif(PX_ENABLE_MSAN AND NOT CMAKE_CXX_COMPILER_ID STREQUAL "Clang")
  log_fatal("PX_ENABLE_MSAN: MSan needs Clang (CC=clang CXX=clang++), not ${CMAKE_CXX_COMPILER_ID}")
elseif(__san_flags)
  # Not every toolchain ships the runtimes (MinGW GCC, for one; TSan, MSan
  # and LSan only exist on some platforms).
  include(CheckCXXSourceCompiles)
  string(MAKE_C_IDENTIFIER "__px_sanitize_${__san_flags}" __san_ok)
  set(CMAKE_REQUIRED_FLAGS "-fsanitize=${__san_flags}")
  set(CMAKE_REQUIRED_QUIET ON)
  check_cxx_source_compiles("int main() { return 0; }" ${__san_ok})
  unset(CMAKE_REQUIRED_FLAGS)
  unset(CMAKE_REQUIRED_QUIET)
  if(NOT ${__san_ok})
    log_fatal("${CMAKE_CXX_COMPILER_ID} ${CMAKE_CXX_COMPILER_VERSION} can't build with -fsanitize=${__san_flags}: "
      "this toolchain has no runtime for it on this platform (PX_ENABLE_*SAN)")
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
