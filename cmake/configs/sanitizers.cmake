#-------------------------------------------------------------------------------
# Sanitizers
#-------------------------------------------------------------------------------

if(MSVC)
  if(ENABLE_UBSAN)
    log_fatal("ENABLE_UBSAN: UBSan is not supported by MSVC, use an ASan-only preset")
  endif()
  # /fsanitize=address rejects /RTC*, which CMake puts in the Debug flags.
  # Dir-scope vars: deps were added earlier and keep theirs (they get no ASan).
  # CMake >= 4.0 has CMAKE_MSVC_RUNTIME_CHECKS for this.
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

  # MSVC: the compiler flag alone pulls in the runtime; link.exe ignores it (LNK4044).
  if(MSVC)
    target_compile_options(${project_name} PRIVATE /fsanitize=${san_flags})
    return()
  endif()

  # Frame pointers: usable ASan stack traces.
  target_compile_options(${project_name} PRIVATE -fsanitize=${san_flags} -fno-omit-frame-pointer)
  target_link_options(${project_name} PRIVATE -fsanitize=${san_flags})

  # UBSan only prints and continues by default: the process (and test) exits 0.
  if(ENABLE_UBSAN)
    target_compile_options(${project_name} PRIVATE -fno-sanitize-recover=undefined)
  endif()

endfunction()
