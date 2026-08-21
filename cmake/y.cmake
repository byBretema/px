# EntryPoint

include_guard(DIRECTORY)
include(${CMAKE_CURRENT_LIST_DIR}/helpers/Logger.cmake)

set(__cmake_helpers_dir ${CMAKE_CURRENT_LIST_DIR} CACHE INTERNAL "")


macro(pre_project)
  log_level_to_notice()
  set(_pre_project_invoked)
endmacro()


macro(post_project)

  log_level_restore()

  if(DEFINED _pre_project_invoked)
    log_warning("Missing 'pre_project()' call.")
  endif()
  unset(_pre_project_invoked)

  log_header("Project: ${PROJECT_NAME}")
  log_status("Compiler for C++ -> ${CMAKE_CXX_COMPILER_ID} ${CMAKE_CXX_COMPILER_VERSION} (${CMAKE_CXX_COMPILER})")
  log_status("Compiler for C   -> ${CMAKE_C_COMPILER_ID} ${CMAKE_C_COMPILER_VERSION} (${CMAKE_C_COMPILER})")

  log_header("Fulfilling dependencies")
  include(${__cmake_helpers_dir}/Dependencies.cmake)

  log_header("Setup")
  include(${__cmake_helpers_dir}/Base.cmake)
  include(${__cmake_helpers_dir}/helpers/Scaffolding.cmake)

  unset(__cmake_helpers_dir)

endmacro()

