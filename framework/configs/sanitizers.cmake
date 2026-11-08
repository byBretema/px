# Sanitizers: PX_ENABLE_ASAN, PX_ENABLE_UBSAN.

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
endif()

function(setup_sanitizers project_name)

  set(san_flags "")

  if(PX_ENABLE_ASAN)
    list(APPEND san_flags address)
  endif()

  if(PX_ENABLE_UBSAN)
    list(APPEND san_flags undefined)
  endif()

  if(NOT san_flags)
    return()
  endif()

  string(REPLACE ";" "," san_flags "${san_flags}")

  # link.exe ignores the flag (LNK4044); the compiler pulls in the runtime.
  if(MSVC)
    target_compile_options(${project_name} PRIVATE /fsanitize=${san_flags})
    return()
  endif()

  target_compile_options(${project_name} PRIVATE -fsanitize=${san_flags} -fno-omit-frame-pointer)
  # Libs: their objects need the runtime, so whatever links them (a plain
  # parent's exe, an installed lib's consumer) links it too.
  get_target_property(type ${project_name} TYPE)
  set(scope PUBLIC)
  if(type STREQUAL "EXECUTABLE")
    set(scope PRIVATE)
  endif()
  target_link_options(${project_name} ${scope} -fsanitize=${san_flags})

  # Otherwise UBSan only prints, and tests pass.
  if(PX_ENABLE_UBSAN)
    target_compile_options(${project_name} PRIVATE -fno-sanitize-recover=undefined)
  endif()

endfunction()
