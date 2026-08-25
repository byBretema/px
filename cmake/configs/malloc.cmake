#-------------------------------------------------------------------------------
# Malloc replacement — mimalloc
#-------------------------------------------------------------------------------

if(USE_MIMALLOC)

  # Fetch mimalloc from source (not header-only, can't use import_dependency)
  include(FetchContent)

  # Build options — disable tests, only need shared lib
  set(MI_BUILD_SHARED  ON  CACHE BOOL "" FORCE)
  set(MI_BUILD_STATIC  OFF CACHE BOOL "" FORCE)
  set(MI_BUILD_OBJECT  OFF CACHE BOOL "" FORCE)
  set(MI_BUILD_TESTS   OFF CACHE BOOL "" FORCE)

  FetchContent_Declare(mimalloc
    GIT_REPOSITORY https://github.com/microsoft/mimalloc.git
    GIT_TAG        v3.5.0
    GIT_SHALLOW    TRUE
  )

  # Force Release — allocator should always be fast regardless of parent build type.
  # Use a non-cache variable to shadow CMAKE_BUILD_TYPE in mimalloc's subdirectory
  # scope without corrupting the cmake cache (avoids reconfigure loops).
  set(__mimalloc_saved_build_type "${CMAKE_BUILD_TYPE}")
  set(CMAKE_BUILD_TYPE "Release")

  log_status("mimalloc: fetching...")
  # log_level_to_notice()
  FetchContent_MakeAvailable(mimalloc)
  # log_level_restore()

  # Restore parent scope
  set(CMAKE_BUILD_TYPE "${__mimalloc_saved_build_type}")

  # Silence mimalloc warnings
  if(MSVC)
    target_compile_options(mimalloc PRIVATE /w)
  else()
    target_compile_options(mimalloc PRIVATE -w)
  endif()

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
