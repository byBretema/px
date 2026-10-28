#-------------------------------------------------------------------------------
# Scaffolding + Tracking targets
#-------------------------------------------------------------------------------


include_guard(DIRECTORY)
include(${CMAKE_CURRENT_LIST_DIR}/logger.cmake)


# Export list per project (global property: written from target subdirs,
# read by setup_export; separate lists when px projects are nested).
function(__register_export name)
  set_property(GLOBAL APPEND PROPERTY __px_export_${PROJECT_NAME} ${name})
endfunction()


# `just run` reads an executable's path from <build>/exe/<name> instead of
# searching the build dir (suffixed -<config> on multi-config generators).
function(__write_exe_path name)
  set(out "${CMAKE_BINARY_DIR}/exe/${name}")
  if(__multi_config)
    string(APPEND out "-$<CONFIG>")
  endif()
  file(GENERATE OUTPUT "${out}" CONTENT "$<TARGET_FILE:${name}>")
endfunction()


# One target = its whole directory tree: every source under `root_dir` is
# compiled, nothing is listed by hand. Code that must not be compiled lives
# outside the target dir; a nested CMakeLists.txt (second target) is an error.
function(__glob_sources root_dir out_sources out_headers)

  file(GLOB_RECURSE _nested CONFIGURE_DEPENDS "${root_dir}/*/CMakeLists.txt")
  if(_nested)
    log_fatal("one target per directory: move nested target(s) out of ${root_dir}: ${_nested}")
  endif()

  file(GLOB_RECURSE _sources CONFIGURE_DEPENDS
    "${root_dir}/*.cpp" "${root_dir}/*.cc" "${root_dir}/*.c" "${root_dir}/*.cxx")
  set(${out_sources} ${_sources} PARENT_SCOPE)

  file(GLOB_RECURSE _headers CONFIGURE_DEPENDS
    "${root_dir}/*.hpp" "${root_dir}/*.hh" "${root_dir}/*.h" "${root_dir}/*.hxx")
  set(${out_headers} ${_headers} PARENT_SCOPE)

endfunction()


# Public headers as a FILE_SET: in-tree consumers get `dir` as include root,
# and setup_export installs the set (subdirs included) next to the library.
function(__add_header_set name scope dir)

  file(GLOB_RECURSE _headers CONFIGURE_DEPENDS
    "${dir}/*.hpp" "${dir}/*.hh" "${dir}/*.h" "${dir}/*.hxx")
  target_sources(${name} ${scope} FILE_SET HEADERS BASE_DIRS "${dir}" FILES ${_headers})

endfunction()


function(make_exe name)

  # Plain name at top level (`just build/run <name>`, binary name). Nested px
  # projects get the project prefix: target names and bin/ files are global.
  set(target ${name})
  if(NOT PROJECT_IS_TOP_LEVEL)
    set(target ${PROJECT_NAME}_${name})
  endif()

  __glob_sources("${CMAKE_CURRENT_SOURCE_DIR}" _sources _headers)
  add_executable(${target} ${_sources} ${_headers} ${ARGN})

  if(TARGET all_dependencies)
    target_link_libraries(${target} PRIVATE all_dependencies)
  endif()

  target_include_directories(${target} PRIVATE
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
    $<BUILD_INTERFACE:${PROJECT_SOURCE_DIR}/vendor>)

  setup_warnings(${target})
  setup_sanitizers(${target})

  __write_exe_path(${target})
  __register_export(${target})

endfunction()


function(make_lib name type)

  # Real name prefixed, as target names are global (nested px projects,
  # deps); link through the alias, which is also the installed name.
  set(target ${PROJECT_NAME}_${name})

  __glob_sources("${CMAKE_CURRENT_SOURCE_DIR}" _sources _headers)
  add_library(${target} ${type} ${_sources} ${ARGN})
  add_library(${PROJECT_NAME}::${name} ALIAS ${target})
  set_target_properties(${target} PROPERTIES EXPORT_NAME ${name})
  __add_header_set(${target} PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}")

  # Build-tree only: fetched deps are not installed, so the export must not
  # reference them (consumers of the installed package provide their own).
  if(TARGET all_dependencies)
    target_link_libraries(${target} PUBLIC $<BUILD_INTERFACE:all_dependencies>)
  endif()

  # Keep symbols of static libs linked into a shared lib (e.g. fmt) private,
  # so they cannot satisfy or clash with a consumer's own copies.
  # MSVC: not needed, DLLs export only dllexport'd symbols.
  # Apple: not covered; ld64 has no --exclude-libs, so dylibs still export
  # them (per-archive -hidden-l<name> / -load_hidden would be needed).
  if(type STREQUAL "SHARED" AND NOT APPLE AND NOT MSVC)
    target_link_options(${target} PRIVATE "LINKER:--exclude-libs,ALL")
  endif()

  target_include_directories(${target} PRIVATE
    $<BUILD_INTERFACE:${PROJECT_SOURCE_DIR}/vendor>)

  setup_warnings(${target})
  setup_sanitizers(${target})

  __register_export(${target})

endfunction()


function(make_lib_header_only name)

  # Prefixed like make_lib.
  set(target ${PROJECT_NAME}_${name})

  add_library(${target} INTERFACE)
  add_library(${PROJECT_NAME}::${name} ALIAS ${target})
  set_target_properties(${target} PROPERTIES EXPORT_NAME ${name})
  __add_header_set(${target} INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}")

  __register_export(${target})

endfunction()


function(make_hlib)
  make_lib_header_only(${ARGN})
endfunction()


function(make_test name)

  __glob_sources("${CMAKE_CURRENT_SOURCE_DIR}" _sources _headers)
  add_executable(${name} ${_sources} ${_headers} ${ARGN})

  if(TARGET all_dependencies)
    target_link_libraries(${name} PRIVATE all_dependencies)
  endif()

  target_include_directories(${name} PRIVATE
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
    $<BUILD_INTERFACE:${PROJECT_SOURCE_DIR}/vendor>)

  setup_warnings(${name})
  setup_sanitizers(${name})

  __write_exe_path(${name})
  add_test(NAME ${name} COMMAND ${name})

endfunction()


# Macro, not function: enable_testing() sets CMAKE_TESTING_ENABLED in the
# current scope, which a function would drop on return (no tests registered).
macro(setup_testing)
  log_header("Testing enabled")
  enable_testing()
endmacro()


# Namespace is PROJECT_NAME, matching the in-tree aliases of make_lib.
# Install rules only for the top-level project: as a subproject, a parent's
# `cmake --install` must not pick them up.
function(setup_export)

  cmake_parse_arguments(ARG "" "" "DEPS" ${ARGN})
  if(NOT PROJECT_IS_TOP_LEVEL)
    return()
  endif()
  log_header("Export")

  set(__export_namespace "${PROJECT_NAME}")
  set(export_set "${__export_namespace}-targets")

  get_property(__export_targets GLOBAL PROPERTY __px_export_${PROJECT_NAME})
  if(NOT __export_targets)
    log_status("No targets registered for export")
    return()
  endif()

  # Deps are not installed: an installed STATIC lib leaves their symbols
  # unresolved for consumers (header-only deps and SHARED libs are fine).
  get_property(compiled_deps GLOBAL PROPERTY __px_compiled_deps)
  list(REMOVE_DUPLICATES compiled_deps)
  foreach(target IN LISTS __export_targets)
    get_target_property(type ${target} TYPE)
    if(type STREQUAL "STATIC_LIBRARY" AND compiled_deps)
      string(JOIN ", " deps ${compiled_deps})
      log_warning("setup_export: installed STATIC lib '${target}' links compiled deps (${deps}), which are not installed: consumers of the package cannot link it. Make it SHARED or keep it free of compiled deps.")
    endif()
  endforeach()

  include(CMakePackageConfigHelpers)

  # One install() per target: each library's headers go to their own
  # include/<ns>/<name>/ (mirrors the in-tree include root, no collisions).
  set(names "")
  foreach(target IN LISTS __export_targets)
    # Exes have no EXPORT_NAME: their target name is the export name.
    get_target_property(export_name ${target} EXPORT_NAME)
    if(NOT export_name)
      set(export_name ${target})
    endif()
    list(APPEND names ${export_name})
    set(header_set "")
    get_target_property(sets ${target} INTERFACE_HEADER_SETS)
    if(sets)
      set(header_set FILE_SET HEADERS
        DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/${__export_namespace}/${export_name})
    endif()
    install(TARGETS ${target}
      EXPORT ${export_set}
      RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
      LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
      ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
      ${header_set})
  endforeach()

  install(EXPORT ${export_set}
    FILE ${export_set}.cmake
    NAMESPACE ${__export_namespace}::
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/${__export_namespace})

  set(config_content "@PACKAGE_INIT@\n\n")
  if(ARG_DEPS)
    string(APPEND config_content "include(CMakeFindDependencyMacro)\n")
  endif()
  foreach(dep ${ARG_DEPS})
    string(APPEND config_content "find_dependency(${dep})\n")
  endforeach()
  string(APPEND config_content "include(\"\${CMAKE_CURRENT_LIST_DIR}/${export_set}.cmake\")\n")
  string(APPEND config_content "check_required_components(${__export_namespace})\n")

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

  string(JOIN ", " names ${names})
  log_status("Export generated (${__export_namespace} :: ${names})")

endfunction()
