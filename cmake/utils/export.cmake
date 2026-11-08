# setup_export([DEPS <find_package names>...])
#
# Install rules of every make_* target and the deps they need, and a package
# for find_package(<PROJECT_NAME>). DEPS: system packages installed targets
# need. Top-level project only.

include_guard(DIRECTORY)


function(setup_export)
  cmake_parse_arguments(ARG "" "" "DEPS" ${ARGN})
  if(NOT PROJECT_IS_TOP_LEVEL)
    return()
  endif()
  log_header("Export")

  set(ns "${PROJECT_NAME}")
  set(export_set "${ns}-targets")
  set(cmake_dest "${CMAKE_INSTALL_LIBDIR}/cmake/${ns}")
  set(config "${CMAKE_BINARY_DIR}/${ns}Config.cmake")
  set(config_version "${CMAKE_BINARY_DIR}/${ns}ConfigVersion.cmake")

  get_property(targets GLOBAL PROPERTY __px_export_${ns})
  if(NOT targets)
    log_status("No targets registered for export")
    return()
  endif()

  set(names "")
  foreach(target IN LISTS targets)
    get_target_property(name ${target} EXPORT_NAME)
    if(NOT name)
      set(name ${target})
    endif()
    list(APPEND names ${name})
    set(header_set "")
    get_target_property(sets ${target} INTERFACE_HEADER_SETS)
    if(sets)
      set(header_set FILE_SET HEADERS DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/${ns}/${name})
    endif()
    install(TARGETS ${target}
      EXPORT ${export_set}
      RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
      LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
      ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
      ${header_set})
  endforeach()

  set(find_deps "")
  foreach(dep IN LISTS ARG_DEPS)
    string(APPEND find_deps "find_dependency(${dep})\n")
  endforeach()
  __install_deps(${export_set} code dep_names ${targets})
  string(APPEND find_deps "${code}")

  install(EXPORT ${export_set} NAMESPACE ${ns}:: DESTINATION ${cmake_dest})

  set(content "@PACKAGE_INIT@\n\n")
  if(find_deps)
    string(APPEND content "include(CMakeFindDependencyMacro)\n${find_deps}")
  endif()
  string(APPEND content
    "include(\"\${CMAKE_CURRENT_LIST_DIR}/${export_set}.cmake\")\n"
    "check_required_components(${ns})\n")
  file(WRITE "${config}.in" "${content}")

  include(CMakePackageConfigHelpers)
  configure_package_config_file("${config}.in" "${config}" INSTALL_DESTINATION "${cmake_dest}")
  install(FILES "${config}" DESTINATION "${cmake_dest}")
  if(PROJECT_VERSION)
    write_basic_package_version_file("${config_version}"
      VERSION ${PROJECT_VERSION} COMPATIBILITY AnyNewerVersion)
    install(FILES "${config_version}" DESTINATION "${cmake_dest}")
  endif()

  string(JOIN ", " names ${names})
  log_status("Export generated (${ns} :: ${names})")
  if(dep_names)
    string(JOIN ", " dep_names ${dep_names})
    log_status("Deps installed -> ${dep_names}")
  endif()

  include(${__base_dir}/configs/package.cmake)
  log_status("Package -> ${CPACK_GENERATOR} (${CPACK_PACKAGE_DIRECTORY})")
endfunction()


#-------------------------------------------------------------------------------
# Internals
#-------------------------------------------------------------------------------

function(__register_export name)
  set_property(GLOBAL APPEND PROPERTY __px_export_${PROJECT_NAME} ${name})
endfunction()


# Each dep through its own install rules, run from its build dir (patches,
# OPTIONS and build type kept), or px-installed headers.
function(__install_deps export_set out_find out_names)
  __needed_deps(interface runtime ${ARGN})
  set(find "")
  set(names "")
  set(done "")
  foreach(wrapper IN LISTS interface runtime)
    get_target_property(name ${wrapper} PX_DEP_NAME)
    get_target_property(real ${wrapper} PX_DEP_REAL)
    get_target_property(script ${wrapper} PX_DEP_INSTALL_SCRIPT)
    get_target_property(headers ${wrapper} PX_DEP_HEADERS)
    list(APPEND names ${name})
    set(public OFF)
    if(wrapper IN_LIST interface)
      set(public ON)
      install(TARGETS ${wrapper} EXPORT ${export_set})
    endif()

    # Several imports may share a dep (same URL).
    if(real)
      set(key "${script}")
    else()
      set(key "${headers}")
    endif()
    if(NOT key IN_LIST done)
      list(APPEND done "${key}")
      if(real)
        install(SCRIPT "${script}")
      else()
        __install_dep_headers("${headers}")
      endif()
    endif()

    if(real AND public)
      __find_dependency_code(code ${wrapper})
      string(FIND "${find}" "${code}" pos)
      if(pos EQUAL -1)
        string(APPEND find "${code}")
      endif()
    endif()
  endforeach()
  set(${out_find} "${find}" PARENT_SCOPE)
  set(${out_names} ${names} PARENT_SCOPE)
endfunction()


# out_interface: consumers link them (static libs' $<LINK_ONLY:> included).
# out_runtime: SHARED deps linked privately, for their runtime files.
function(__needed_deps out_interface out_runtime)
  __link_closure(interface "INTERFACE_LINK_LIBRARIES" BUILD_INTERFACE ${ARGN})
  list(FILTER interface INCLUDE REGEX "^__px_dep_")
  __link_closure(linked "LINK_LIBRARIES;INTERFACE_LINK_LIBRARIES" INSTALL_INTERFACE ${ARGN})
  set(runtime "")
  foreach(item IN LISTS linked)
    get_target_property(type ${item} TYPE)
    get_property(wrapper GLOBAL PROPERTY __px_dep_of_${item})
    if(type STREQUAL "SHARED_LIBRARY" AND wrapper AND NOT wrapper IN_LIST interface)
      list(APPEND runtime ${wrapper})
    endif()
  endforeach()
  set(${out_interface} ${interface} PARENT_SCOPE)
  set(${out_runtime} ${runtime} PARENT_SCOPE)
endfunction()


# SUBDIR may be the repo root: non-API dirs dropped. Per file, as
# install(DIRECTORY FILES_MATCHING) also creates every other dir, empty.
function(__install_dep_headers root)
  __ext_patterns(patterns "${root}" ${__header_exts} inl ipp tcc)
  file(GLOB_RECURSE files RELATIVE "${root}" ${patterns})
  list(FILTER files EXCLUDE REGEX "(^|/)(\\.git|tests?|examples?|docs?|bench(mark)?s?)/")
  set(dirs "")
  foreach(file IN LISTS files)
    cmake_path(GET file PARENT_PATH dir)
    # Empty items vanish from lists: the root is ".".
    if(dir STREQUAL "")
      set(dir .)
    endif()
    string(MAKE_C_IDENTIFIER "files_${dir}" key)
    list(APPEND ${key} "${root}/${file}")
    list(APPEND dirs "${dir}")
  endforeach()
  list(REMOVE_DUPLICATES dirs)
  foreach(dir IN LISTS dirs)
    string(MAKE_C_IDENTIFIER "files_${dir}" key)
    # NORMAL_PATH: "include/." would trip CMP0177.
    cmake_path(APPEND CMAKE_INSTALL_INCLUDEDIR ${dir} OUTPUT_VARIABLE dest)
    cmake_path(NORMAL_PATH dest)
    install(FILES ${${key}} DESTINATION ${dest})
  endforeach()
endfunction()


# HINTS: the bundled copy wins over others on the consumer's path. A compiled
# dep the consumer already loaded wins anyway; another version would link
# mismatched, so stop.
function(__find_dependency_code out wrapper)
  get_target_property(package ${wrapper} PX_DEP_PACKAGE)
  get_target_property(version ${wrapper} PX_DEP_VERSION)
  get_target_property(type ${wrapper} PX_DEP_TYPE)
  if(NOT version)
    set(version "")
  endif()
  string(STRIP "${package} ${version}" args)
  set(code "find_dependency(${args} CONFIG HINTS \"\${PACKAGE_PREFIX_DIR}\")\n")
  if(version AND NOT type STREQUAL "INTERFACE_LIBRARY")
    string(PREPEND code
      "if(DEFINED ${package}_VERSION AND NOT ${package}_VERSION VERSION_EQUAL ${version})\n"
      "  message(FATAL_ERROR \"${PROJECT_NAME} was built with ${package} ${version}, but ${package} "
      "\${${package}_VERSION} is already loaded (\${${package}_DIR}): use ${version}, "
      "or find_package(${PROJECT_NAME}) before ${package}\")\n"
      "endif()\n")
  endif()
  set(${out} "${code}" PARENT_SCOPE)
endfunction()
