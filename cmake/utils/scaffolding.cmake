# Targets: one per directory, its whole tree globbed.
#
#   make_exe(<name> [DEPS ...] [<extra sources>...])
#   make_lib(<name> SHARED|STATIC|HEADER_ONLY [DEPS ...] [PRIVATE_DEPS ...] [<extra sources>...])
#   make_hlib(<name> [DEPS ...])                          (make_lib HEADER_ONLY)
#   make_test(<name> [DEPS ...] [<extra sources>...])
#
# DEPS: used by public headers (libs) or at all (exes); PRIVATE_DEPS: by lib
# sources only, and left out of a SHARED lib's installed package.

include_guard(DIRECTORY)
include(${CMAKE_CURRENT_LIST_DIR}/logger.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/sources.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/export.cmake)


# Target names are global: prefixed when nested, and always for libs (used
# through the <project>::<name> alias, which is also the installed name).
function(make_exe name)
  set(target ${name})
  if(NOT PROJECT_IS_TOP_LEVEL)
    set(target ${PROJECT_NAME}_${name})
  endif()
  __make_target(${target} EXE ${ARGN})
  __register_export(${target})
endfunction()


function(make_lib name kind)
  if(NOT kind MATCHES "^(SHARED|STATIC|HEADER_ONLY)$")
    log_fatal("make_lib(${name}): type must be SHARED, STATIC or HEADER_ONLY, got '${kind}'")
  endif()
  set(target ${PROJECT_NAME}_${name})
  __make_target(${target} ${kind} ${ARGN})
  add_library(${PROJECT_NAME}::${name} ALIAS ${target})
  set_target_properties(${target} PROPERTIES EXPORT_NAME ${name})
  __register_export(${target})
endfunction()


function(make_hlib name)
  make_lib(${name} HEADER_ONLY ${ARGN})
endfunction()


function(make_test name)
  __make_target(${name} EXE ${ARGN})
  add_test(NAME ${name} COMMAND ${name})
endfunction()


# Macro: enable_testing() must run in the caller's scope.
macro(setup_testing)
  log_header("Testing enabled")
  enable_testing()
endmacro()


#-------------------------------------------------------------------------------
# Internals
#-------------------------------------------------------------------------------

# A lib's dir is the include root of its public headers.
function(__make_target target kind)
  cmake_parse_arguments(ARG "" "" "DEPS;PRIVATE_DEPS" ${ARGN})
  set(dir "${CMAKE_CURRENT_SOURCE_DIR}")

  file(GLOB_RECURSE nested CONFIGURE_DEPENDS "${dir}/*/CMakeLists.txt")
  if(nested)
    log_fatal("one target per directory: move nested target(s) out of ${dir}: ${nested}")
  endif()
  __ext_patterns(patterns "${dir}" ${__source_exts})
  file(GLOB_RECURSE sources CONFIGURE_DEPENDS ${patterns})
  __ext_patterns(patterns "${dir}" ${__header_exts})
  file(GLOB_RECURSE headers CONFIGURE_DEPENDS ${patterns})
  list(APPEND sources ${ARG_UNPARSED_ARGUMENTS})

  if(kind STREQUAL "EXE")
    set(scope PRIVATE)
    add_executable(${target} ${sources} ${headers})
    target_include_directories(${target} PRIVATE "${dir}")
    __write_exe_path(${target})
  elseif(kind STREQUAL "HEADER_ONLY")
    if(sources OR ARG_PRIVATE_DEPS)
      log_fatal("header-only lib in ${dir}: no sources or PRIVATE_DEPS allowed, got ${sources} ${ARG_PRIVATE_DEPS}")
    endif()
    set(scope INTERFACE)
    add_library(${target} INTERFACE)
  else()
    set(scope PUBLIC)
    add_library(${target} ${kind} ${sources})
  endif()
  if(NOT kind STREQUAL "EXE")
    target_sources(${target} ${scope} FILE_SET HEADERS BASE_DIRS "${dir}" FILES ${headers})
  endif()

  target_compile_features(${target} ${scope} ${__cxx_std})
  __link_deps(${target} ${scope} ${ARG_DEPS})
  if(scope STREQUAL "INTERFACE")
    return()
  endif()
  __link_deps(${target} PRIVATE ${ARG_PRIVATE_DEPS})
  target_include_directories(${target} PRIVATE "${PROJECT_SOURCE_DIR}/vendor")
  setup_warnings(${target})
  setup_sanitizers(${target})

  if(kind STREQUAL "SHARED")
    # Deferred, so links added after make_lib count. EVAL: DEFER would
    # expand ${target} only when the call runs.
    cmake_language(EVAL CODE
      "cmake_language(DEFER DIRECTORY [[${CMAKE_SOURCE_DIR}]] CALL __hide_static_deps [[${target}]])")
  endif()
endfunction()


# Through the px wrapper even when the dep owns the ns::target name.
function(__link_deps target scope)
  foreach(dep IN LISTS ARGN)
    __dep_wrapper(wrapper ${dep})
    if(TARGET ${wrapper})
      set(dep ${wrapper})
    endif()
    target_link_libraries(${target} ${scope} ${dep})
  endforeach()
endfunction()


# For `just run`.
function(__write_exe_path name)
  set(out "${CMAKE_BINARY_DIR}/exe/${name}")
  if(__multi_config)
    string(APPEND out "-$<CONFIG>")
  endif()
  file(GENERATE OUTPUT "${out}" CONTENT "$<TARGET_FILE:${name}>")
endfunction()


# Static deps' symbols (fmt) stay private to the shared lib, so they can't
# clash with a consumer's copies. MSVC DLLs export only dllexport'd ones.
function(__hide_static_deps target)
  if(MSVC)
    return()
  endif()
  if(NOT APPLE)
    target_link_options(${target} PRIVATE "LINKER:--exclude-libs,ALL")
    return()
  endif()
  # ld64 has no --exclude-libs. It resolves from an archive's first copy,
  # and these options precede the link libraries.
  __link_closure(linked "LINK_LIBRARIES;INTERFACE_LINK_LIBRARIES" INSTALL_INTERFACE ${target})
  foreach(dep IN LISTS linked)
    get_target_property(type ${dep} TYPE)
    get_target_property(imported ${dep} IMPORTED)
    if(type STREQUAL "STATIC_LIBRARY" AND NOT imported)
      target_link_options(${target} PRIVATE "LINKER:-load_hidden,$<TARGET_FILE:${dep}>")
    endif()
  endforeach()
endfunction()


# Targets reachable from ARGN through `props`, imported ones not walked.
# Genexes: `$<skip:...>` (BUILD_ or INSTALL_INTERFACE) is dropped, then any
# word naming a target counts ($<LINK_ONLY:x>, both $<CONFIG> branches).
function(__link_closure out props skip)
  set(found "")
  set(queue ${ARGN})
  while(queue)
    list(POP_FRONT queue item)
    if(NOT TARGET ${item})
      continue()
    endif()
    get_target_property(aliased ${item} ALIASED_TARGET)
    if(aliased)
      set(item ${aliased})
    endif()
    if(item IN_LIST found)
      continue()
    endif()
    list(APPEND found ${item})
    get_target_property(imported ${item} IMPORTED)
    if(imported)
      continue()
    endif()
    foreach(prop IN LISTS props)
      get_target_property(value ${item} ${prop})
      if(value)
        string(REGEX REPLACE "\\$<${skip}:[^>]*>" "" value "${value}")
        string(REGEX MATCHALL "[A-Za-z0-9_.+-]+(::[A-Za-z0-9_.+-]+)*" words "${value}")
        list(APPEND queue ${words})
      endif()
    endforeach()
  endwhile()
  set(${out} ${found} PARENT_SCOPE)
endfunction()
