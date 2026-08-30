#-------------------------------------------------------------------------------
# Malloc replacement — mimalloc
#-------------------------------------------------------------------------------

if(USE_MIMALLOC)
  import_dependency(mimalloc::mimalloc
    GITHUB      microsoft/mimalloc
    TAG         v3.5.0
    BUILD_TYPE  Release
    OPTIONS     MI_BUILD_SHARED=ON
                MI_BUILD_STATIC=OFF
                MI_BUILD_OBJECT=OFF
                MI_BUILD_TESTS=OFF
  )
endif()

#--- Link function -----------------------------------------------------------
function(target_link_mimalloc target)
  if(NOT USE_MIMALLOC)
    log_status("mimalloc: disabled")
    return()
  endif()

  # Skip under sanitizers — mimalloc replaces the allocator which conflicts
  if(ENABLE_ASAN OR ENABLE_UBSAN)
    log_status("mimalloc: disabled")
    return()
  endif()

  # Silence mimalloc warnings
  if(MSVC)
    target_compile_options(mimalloc PRIVATE /w)
  else()
    target_compile_options(mimalloc PRIVATE -w)
  endif()

  if(WIN32 AND MSVC)
    # Windows: force-link mimalloc via mi_version symbol
    log_status("mimalloc: enabled")
    target_link_libraries(${target} PRIVATE mimalloc)
    target_link_options(${target} PRIVATE "/INCLUDE:mi_version")

    # Copy mimalloc DLLs next to the binary
    add_custom_command(TARGET ${target} POST_BUILD
      COMMAND ${CMAKE_COMMAND} -E copy_if_different
        $<TARGET_FILE:mimalloc>
        $<TARGET_FILE_DIR:${target}>
      COMMAND ${CMAKE_COMMAND} -E copy_if_different
        "${mimalloc_BINARY_DIR}/mimalloc-redirect.dll"
        $<TARGET_FILE_DIR:${target}>
      COMMENT "Copying mimalloc DLLs to output directory"
    )

  elseif(APPLE)
    # macOS: use interpose (mimalloc enables MI_OSX_INTERPOSE by default)
    log_status("mimalloc: enabled")
    target_link_libraries(${target} PRIVATE mimalloc)

  else()
    # Linux: force ELF symbol interposition with --no-as-needed
    log_status("mimalloc: enabled")
    target_link_libraries(${target} PRIVATE "-Wl,--no-as-needed" mimalloc)
  endif()

  target_compile_definitions(${target} PRIVATE USE_MIMALLOC)

endfunction()
