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

  set(__pre_project_done ON)

  # Set by CMakePresets.json. Lets tools (justfile) reuse the last configured
  # preset and find its build dir: line 1 = preset, line 2 = binary dir.
  if(ACTIVE_PRESET)
    file(WRITE "${CMAKE_SOURCE_DIR}/.build/active_preset" "${ACTIVE_PRESET}\n${CMAKE_BINARY_DIR}\n")
  endif()

endmacro()


macro(post_project)

  log_level_restore()

  if(NOT __pre_project_done)
    log_warning("Missing 'pre_project()' call.")
  endif()
  unset(__pre_project_done)

  include(${__base_dir}/utils/scaffolding.cmake)

  # Multi-config generators (VS, Xcode, Ninja Multi-Config) ignore
  # CMAKE_BUILD_TYPE: the config is picked at build time (--config).
  get_property(__multi_config GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
  if(NOT __multi_config AND NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Release CACHE STRING "" FORCE)
  endif()

  log_ln()
  log_status("Project -> ${PROJECT_NAME}")

  if(__multi_config)
    string(JOIN "/" __build_type ${CMAKE_CONFIGURATION_TYPES})
    set(__build_type "multi-config: ${__build_type}")
  else()
    set(__build_type "${CMAKE_BUILD_TYPE}")
  endif()
  if(ACTIVE_PRESET)
    log_status("Preset  -> ${ACTIVE_PRESET} (${__build_type}, ${CMAKE_BINARY_DIR})")
  else()
    log_status("Preset  -> none (${__build_type})")
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

  # Generated files must go to the build dir: in a globbed project dir they
  # would be compiled. Set last, so the deps/active_preset writes above pass.
  set(CMAKE_DISABLE_SOURCE_CHANGES ON)

endmacro()
