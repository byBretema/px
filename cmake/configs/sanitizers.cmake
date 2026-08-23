#-------------------------------------------------------------------------------
# Sanitizers
#-------------------------------------------------------------------------------

function(setup_sanitizers project_name)
  set(san_flags "")
  if(ENABLE_ASAN)
    list(APPEND san_flags address)
  endif()
  if(ENABLE_UBSAN)
    list(APPEND san_flags undefined)
  endif()
  if(san_flags)
    string(REPLACE ";" "," san_flags "${san_flags}")
    target_compile_options(${project_name} PRIVATE -fsanitize=${san_flags})
    target_link_options(${project_name} PRIVATE -fsanitize=${san_flags})
  endif()
endfunction()
