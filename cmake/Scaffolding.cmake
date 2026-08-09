# Scaffolding helpers + Tracking targets

include_guard(DIRECTORY)
include(${CMAKE_CURRENT_LIST_DIR}/Logger.cmake)

set(__export_namespace "${PROJECT_NAME}" CACHE INTERNAL "Namespace for install targets")
set(__export_targets "" CACHE INTERNAL "Targets registered for export")


function(__glob_sources root_dir out_sources out_headers)
  file(GLOB _sources CONFIGURE_DEPENDS
    "${root_dir}/*.cpp" "${root_dir}/*.cc" "${root_dir}/*.c" "${root_dir}/*.cxx")
  file(GLOB _headers CONFIGURE_DEPENDS
    "${root_dir}/*.hpp" "${root_dir}/*.hh" "${root_dir}/*.h" "${root_dir}/*.hxx")
  set(${out_sources} ${_sources} PARENT_SCOPE)
  set(${out_headers} ${_headers} PARENT_SCOPE)
endfunction()


macro(make_exe name)
  __glob_sources("${CMAKE_CURRENT_SOURCE_DIR}" _sources _headers)
  add_executable(${name} ${_sources} ${_headers} ${ARGN})
  if(TARGET all_dependencies)
    target_link_libraries(${name} PRIVATE all_dependencies)
  endif()
  target_include_directories(${name} PRIVATE
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
    $<BUILD_INTERFACE:${CMAKE_SOURCE_DIR}/vendor>)
  setup_warnings(${name})
  setup_sanitizers(${name})
  list(APPEND __export_targets ${name})
  set(__export_targets "${__export_targets}" CACHE INTERNAL "")
endmacro()


macro(make_lib name type)
  __glob_sources("${CMAKE_CURRENT_SOURCE_DIR}" _sources _headers)
  add_library(${name} ${type} ${_sources} ${_headers} ${ARGN})
  if(TARGET all_dependencies)
    target_link_libraries(${name} PUBLIC all_dependencies)
  endif()
  target_include_directories(${name} PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
    $<INSTALL_INTERFACE:include/${__export_namespace}>)
  target_include_directories(${name} PRIVATE
    $<BUILD_INTERFACE:${CMAKE_SOURCE_DIR}/vendor>)
  setup_warnings(${name})
  setup_sanitizers(${name})
  list(APPEND __export_targets ${name})
  set(__export_targets "${__export_targets}" CACHE INTERNAL "")
endmacro()


macro(make_lib_header_only name)
  add_library(${name} INTERFACE)
  __glob_sources("${CMAKE_CURRENT_SOURCE_DIR}" _sources _headers)
  if(_headers)
    target_sources(${name} INTERFACE ${_headers})
  endif()
  target_include_directories(${name} INTERFACE
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
    $<INSTALL_INTERFACE:include/${__export_namespace}>)
  list(APPEND __export_targets ${name})
  set(__export_targets "${__export_targets}" CACHE INTERNAL "")
endmacro()


macro(make_hlib)
  make_lib_header_only(${ARGN})
endmacro()


macro(make_test name)
  __glob_sources("${CMAKE_CURRENT_SOURCE_DIR}" _sources _headers)
  add_executable(${name} ${_sources} ${_headers} ${ARGN})
  if(TARGET all_dependencies)
    target_link_libraries(${name} PRIVATE all_dependencies)
  endif()
  target_include_directories(${name} PRIVATE
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
    $<BUILD_INTERFACE:${CMAKE_SOURCE_DIR}/vendor>)
  setup_warnings(${name})
  setup_sanitizers(${name})
  add_test(NAME ${name} COMMAND ${name})
endmacro()


# macro(link_dependencies target)
#   target_link_libraries(${target} PRIVATE ${ARGN})
# endmacro()


macro(setup_testing)
  if(PROJECT_IS_TOP_LEVEL)
    log_header("Testing enabled")
    enable_testing()
  endif()
endmacro()


function(setup_export)
  cmake_parse_arguments(ARG "" "NAMESPACE" "DEPS" ${ARGN})
  log_header("Export")

  if(ARG_NAMESPACE)
    set(__export_namespace "${ARG_NAMESPACE}" CACHE INTERNAL "")
  endif()
  set(export_set "${__export_namespace}-targets")

  if(NOT __export_targets)
    log_status("No targets registered for export")
    return()
  endif()

  include(CMakePackageConfigHelpers)

  install(TARGETS ${__export_targets}
    EXPORT ${export_set}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
    INCLUDES DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})

  install(EXPORT ${export_set}
    FILE ${export_set}.cmake
    NAMESPACE ${__export_namespace}::
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/${__export_namespace})

  set(config_content "@PACKAGE_INIT@\n\n")
  foreach(dep ${ARG_DEPS})
    string(APPEND config_content "find_dependency(${dep})\n")
  endforeach()
  string(APPEND config_content "include(\"\${CMAKE_CURRENT_LIST_DIR}/${export_set}.cmake\")\n")
  string(APPEND config_content "set(${__export_namespace}_FOUND TRUE)\n")

  set(config_in_path "${CMAKE_BINARY_DIR}/${__export_namespace}Config.cmake.in")
  file(WRITE "${config_in_path}" "${config_content}")

  configure_package_config_file(
    "${config_in_path}"
    "${CMAKE_BINARY_DIR}/${__export_namespace}Config.cmake"
    INSTALL_DESTINATION "${CMAKE_INSTALL_LIBDIR}/cmake/${__export_namespace}")

  install(FILES "${CMAKE_BINARY_DIR}/${__export_namespace}Config.cmake"
    DESTINATION "${CMAKE_INSTALL_LIBDIR}/cmake/${__export_namespace}")

  if(PROJECT_VERSION)
    write_basic_package_version_file(
      "${CMAKE_BINARY_DIR}/${__export_namespace}ConfigVersion.cmake"
      VERSION ${PROJECT_VERSION}
      COMPATIBILITY AnyNewerVersion)
    install(FILES "${CMAKE_BINARY_DIR}/${__export_namespace}ConfigVersion.cmake"
      DESTINATION "${CMAKE_INSTALL_LIBDIR}/cmake/${__export_namespace}")
  endif()

  log_status("Export generated (${__export_namespace} :: ${__export_targets})")
endfunction()
