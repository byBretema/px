# Sanitizers: ENABLE_ASAN, ENABLE_UBSAN.

if(MSVC)
  if(ENABLE_UBSAN)
    log_fatal("ENABLE_UBSAN: UBSan is not supported by MSVC, use an ASan-only preset")
  endif()
  # /fsanitize=address rejects CMake's Debug /RTC*. Deps keep theirs (no ASan).
  if(ENABLE_ASAN)
    foreach(lang C CXX)
      string(REGEX REPLACE "/RTC[1csu]*" "" CMAKE_${lang}_FLAGS_DEBUG "${CMAKE_${lang}_FLAGS_DEBUG}")
    endforeach()
  endif()
endif()

function(setup_sanitizers project_name)

  set(san_flags "")

  if(ENABLE_ASAN)
    list(APPEND san_flags address)
  endif()

  if(ENABLE_UBSAN)
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
  target_link_options(${project_name} PRIVATE -fsanitize=${san_flags})

  # Otherwise UBSan only prints, and tests pass.
  if(ENABLE_UBSAN)
    target_compile_options(${project_name} PRIVATE -fno-sanitize-recover=undefined)
  endif()

endfunction()
