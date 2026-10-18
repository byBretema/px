#-------------------------------------------------------------------------------
# EntryPoint
#-------------------------------------------------------------------------------


include_guard(DIRECTORY)
include(${CMAKE_CURRENT_LIST_DIR}/utils/logger.cmake)

set(__base_dir ${CMAKE_CURRENT_LIST_DIR} CACHE INTERNAL "")


macro(pre_project)

  log_level_to_notice()

  if(CMAKE_SOURCE_DIR STREQUAL CMAKE_BINARY_DIR)
    message(FATAL_ERROR "In-source builds are forbidden. Use -B build")
  endif()

  set(__pre_project_invoked ON CACHE INTERNAL "'pre_project' invoked correctly")

  # Set by CMakePresets.json. Lets tools (justfile) reuse the last configured
  # preset and find its build dir: line 1 = preset, line 2 = binary dir.
  if(ACTIVE_PRESET)
    file(WRITE "${CMAKE_SOURCE_DIR}/.build/active_preset" "${ACTIVE_PRESET}\n${CMAKE_BINARY_DIR}\n")
  endif()

endmacro()


macro(post_project)

  log_level_restore()

  if(NOT DEFINED __pre_project_invoked)
    log_warning("Missing 'pre_project()' call.")
  endif()
  unset(__pre_project_invoked)

  include(${__base_dir}/utils/scaffolding.cmake)

  if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Release CACHE STRING "" FORCE)
  endif()

  log_ln()
  log_status("Project -> ${PROJECT_NAME}")

  if(ACTIVE_PRESET)
    log_status("Preset  -> ${ACTIVE_PRESET} (${CMAKE_BUILD_TYPE}, ${CMAKE_BINARY_DIR})")
  else()
    log_status("Preset  -> none")
  endif()

  # Toolchain: must precede deps so they inherit it
  log_header("Toolchain")

  log_status("Compiler for C++ -> ${CMAKE_CXX_COMPILER_ID} ${CMAKE_CXX_COMPILER_VERSION} (${CMAKE_CXX_COMPILER})")
  log_status("Compiler for C   -> ${CMAKE_C_COMPILER_ID} ${CMAKE_C_COMPILER_VERSION} (${CMAKE_C_COMPILER})")

  include(${__base_dir}/configs/options.cmake)
  include(${__base_dir}/configs/compile_commands.cmake)

  log_ln()
  include(${__base_dir}/configs/cache.cmake)
  include(${__base_dir}/configs/linker.cmake)
  include(${__base_dir}/configs/global.cmake)

  # Deps
  log_header("Dependencies")

  include(${__base_dir}/deps.cmake)
  include(${__base_dir}/configs/malloc.cmake)

  # Project setup: own targets only
  # log_header("Setup")

  include(${__base_dir}/configs/defaults.cmake)
  include(${__base_dir}/configs/warnings.cmake)
  include(${__base_dir}/configs/sanitizers.cmake)
  include(${__base_dir}/utils/manifest.cmake)

  set(CMAKE_DISABLE_SOURCE_CHANGES ON)
  set(CMAKE_DISABLE_IN_SOURCE_BUILD ON)

endmacro()
