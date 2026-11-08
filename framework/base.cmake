# px entry point: pre_project() / post_project() around project().

include_guard(DIRECTORY)
include(${CMAKE_CURRENT_LIST_DIR}/utils/logger.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/version.cmake)

# Not cache: a nested px project needs its own.
set(__base_dir ${CMAKE_CURRENT_LIST_DIR})


macro(pre_project)

  log_level_to_notice()

  if(CMAKE_SOURCE_DIR STREQUAL CMAKE_BINARY_DIR)
    message(FATAL_ERROR "In-source builds are forbidden. Use -B build")
  endif()

  set(__pre_project_done ON)

  # For the justfile: preset, build dir, px dir. Before project():
  # PROJECT_IS_TOP_LEVEL isn't set yet.
  if(PX_ACTIVE_PRESET AND CMAKE_CURRENT_SOURCE_DIR STREQUAL CMAKE_SOURCE_DIR)
    file(WRITE "${CMAKE_SOURCE_DIR}/.build/active_preset" "${PX_ACTIVE_PRESET}\n${CMAKE_BINARY_DIR}\n${__base_dir}\n")
  endif()

endmacro()


macro(post_project)

  log_level_restore()

  if(NOT __pre_project_done)
    log_warning("Missing 'pre_project()' call.")
  endif()
  unset(__pre_project_done)

  # Inherited from a parent px project; would block dep fetches. Set again at the end.
  unset(CMAKE_DISABLE_SOURCE_CHANGES)

  include(${__base_dir}/utils/scaffolding.cmake)

  get_property(__multi_config GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
  if(NOT __multi_config AND NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Release CACHE STRING "" FORCE)
  endif()

  log_ln()
  log_status("px      -> ${PX_VERSION} (${__base_dir})")
  log_status("Project -> ${PROJECT_NAME}")

  if(__multi_config)
    string(JOIN "/" __build_type ${CMAKE_CONFIGURATION_TYPES})
    set(__build_type "multi-config: ${__build_type}")
  else()
    set(__build_type "${CMAKE_BUILD_TYPE}")
  endif()
  if(PX_ACTIVE_PRESET)
    log_status("Preset  -> ${PX_ACTIVE_PRESET} (${__build_type}, ${CMAKE_BINARY_DIR})")
  else()
    log_status("Preset  -> none (${__build_type})")
  endif()

  # Before deps, so they inherit it.
  log_header("Toolchain")

  log_status("Compiler for C++ -> ${CMAKE_CXX_COMPILER_ID} ${CMAKE_CXX_COMPILER_VERSION} (${CMAKE_CXX_COMPILER})")
  log_status("Compiler for C   -> ${CMAKE_C_COMPILER_ID} ${CMAKE_C_COMPILER_VERSION} (${CMAKE_C_COMPILER})")

  include(${__base_dir}/configs/compiler.cmake)
  include(${__base_dir}/configs/options.cmake)
  include(${__base_dir}/configs/compile_commands.cmake)

  log_ln()
  include(${__base_dir}/configs/cache.cmake)
  include(${__base_dir}/configs/linker.cmake)
  include(${__base_dir}/configs/global.cmake)

  log_header("Dependencies")

  include(${__base_dir}/utils/importer.cmake)
  include(${PROJECT_SOURCE_DIR}/cmake/deps.cmake OPTIONAL)

  # After deps: own targets only.
  include(${__base_dir}/configs/defaults.cmake)
  include(${__base_dir}/configs/warnings.cmake)
  include(${__base_dir}/configs/sanitizers.cmake)

  # Generated files in a globbed target dir would be compiled.
  set(CMAKE_DISABLE_SOURCE_CHANGES ON)

endmacro()
