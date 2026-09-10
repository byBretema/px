#-------------------------------------------------------------------------------
# Importer utils
#-------------------------------------------------------------------------------

include(FetchContent)

set(CMAKE_POLICY_VERSION_MINIMUM 3.10)
set(CMAKE_POLICY_DEFAULT_CMP0135 NEW)

set(FETCHCONTENT_BASE_DIR "${DEPS_DIR}")
set(FETCHCONTENT_QUIET ON)

add_library(all_dependencies INTERFACE)

macro(__add_dependency namespace target fetch_id subdir)
  if(NOT TARGET ${namespace}::${target})
    # 3-step target lookup: qualified → plain → underscore
    set(_candidates
      ${namespace}::${target}
      ${target}
      ${namespace}_${target}
    )
    set(_real_target "")
    foreach(_name IN LISTS _candidates)
      if(TARGET ${_name})
        set(_real_target ${_name})
        break()
      endif()
    endforeach()

    add_library(${namespace}_${target} INTERFACE)
    target_include_directories(${namespace}_${target} INTERFACE
      "${${fetch_id}_SOURCE_DIR}/${subdir}")

    # Link compiled targets (skip INTERFACE — headers only).
    if(_real_target)
      get_target_property(_type ${_real_target} TYPE)
      if(NOT _type STREQUAL "INTERFACE_LIBRARY")
        target_link_libraries(${namespace}_${target} INTERFACE ${_real_target})
      endif()
    endif()

    add_library(${namespace}::${target} ALIAS ${namespace}_${target})
  endif()

  target_link_libraries(all_dependencies INTERFACE ${namespace}::${target})
endmacro()

#-------------------------------------------------------------------------------
# import_dependency — FetchContent declaration, population, and target creation.
#   Works for header-only, static, and shared libraries.
#   Auto-detects the target type via the TYPE property after MakeAvailable.
#
#   qualified_target   CMake target name in the form "namespace::target".
#                      This becomes the actual target users link against.
#
#   REPOSITORY         Full Git repository URL (https). Mutually exclusive with the shorthand keys below.
#       GITHUB             GitHub shorthand "org/repo"     →  https://github.com/org/repo.git
#       GITLAB             GitLab shorthand "org/repo"     →  https://gitlab.com/org/repo.git
#       BITBUCKET          Bitbucket shorthand "org/repo"  →  https://bitbucket.org/org/repo.git
#   TAG                Git tag, branch, or commit hash.
#   SUBDIR             Include subdirectory relative to the source root
#                      (e.g. "include", ".", "asio/include").
#   BUILD_TYPE         (optional) Override DEPS_BUILD_TYPE for this dep.
#   OPTIONS            (optional) CMake variables to set before the library's
#                      own CMake runs.  Pass as KEY=VALUE pairs.
#
# Exactly one of REPOSITORY / GITHUB / GITLAB / BITBUCKET must be given.
# Multiple calls sharing the same URL are safe — the fetch happens only
# once and the include directory is shared.
#-------------------------------------------------------------------------------
function(import_dependency qualified_target)
  cmake_parse_arguments(ARG "" "REPOSITORY;GITHUB;GITLAB;BITBUCKET;TAG;SUBDIR;PATCH;BUILD_TYPE" "OPTIONS" ${ARGN})

  # --- Resolve repository URL from shorthand or full URL ---
  set(shorthand "")
  set(repo_url "")
  if(ARG_REPOSITORY)
    set(repo_url "${ARG_REPOSITORY}")
  elseif(ARG_GITHUB)
    set(repo_url "https://github.com/${ARG_GITHUB}.git")
    set(shorthand "${ARG_GITHUB}")
  elseif(ARG_GITLAB)
    set(repo_url "https://gitlab.com/${ARG_GITLAB}.git")
    set(shorthand "${ARG_GITLAB}")
  elseif(ARG_BITBUCKET)
    set(repo_url "https://bitbucket.org/${ARG_BITBUCKET}.git")
    set(shorthand "${ARG_BITBUCKET}")
  else()
    log_fatal("import_dependency: one of REPOSITORY / GITHUB / GITLAB / BITBUCKET is required")
  endif()

  # --- Validate required arguments ---
  if(NOT ARG_TAG)
    log_fatal("import_dependency: TAG is required")
  endif()

  if(NOT ARG_SUBDIR)
    log_fatal("import_dependency: SUBDIR is required")
  endif()

  # --- Parse qualified_target into namespace and target ---
  string(REPLACE "::" ";" parts "${qualified_target}")
  list(LENGTH parts len)
  if(NOT len EQUAL 2)
    log_fatal("import_dependency: first arg must be ns::target, got '${qualified_target}'")
  endif()
  list(GET parts 0 ns)
  list(GET parts 1 target)

  # --- Derive a unique FetchContent ID from the URL ---
  if(shorthand)
    set(fetch_id "${shorthand}")
  else()
    string(REGEX REPLACE "^https?://[^/]+/" "" fetch_id "${repo_url}")
    string(REGEX REPLACE "\\.git$" "" fetch_id "${fetch_id}")
  endif()
  string(REPLACE "/" "_" fetch_id "${fetch_id}")
  string(TOLOWER "${fetch_id}" fetch_id)

  # --- Apply OPTIONS before fetch guard ---
  # CACHE FORCE is the only mechanism that overrides dep-defined cache
  # entries (e.g. FMT_DEBUG_POSTFIX=d) before add_subdirectory creates
  # the child scope. CMAKE_ARGS is a no-op for add_subdirectory paths.
  foreach(opt ${ARG_OPTIONS})
    if(opt MATCHES "^([^=]+)=(.*)$")
      set(${CMAKE_MATCH_1} "${CMAKE_MATCH_2}" CACHE STRING "" FORCE)
    else()
      log_fatal("import_dependency: OPTIONS must be KEY=VALUE, got: ${opt}")
    endif()
  endforeach()

  # --- Fetch the dependency (only once per fetch_id) ---
  set(fetch_guard __fetched_${fetch_id})
  if(NOT DEFINED ${fetch_guard})
    # --- Build type for this dep (overrides DEPS_BUILD_TYPE) ---
    set(_dep_build_type "${DEPS_BUILD_TYPE}")
    if(DEFINED ARG_BUILD_TYPE)
      set(_dep_build_type "${ARG_BUILD_TYPE}")
    endif()

    # Pass build type via CMAKE_ARGS (ExternalProject fallback only).
    set(_dep_cmake_args "")
    if(_dep_build_type)
      list(APPEND _dep_cmake_args -DCMAKE_BUILD_TYPE=${_dep_build_type})
    endif()

    FetchContent_Declare(${fetch_id}
      GIT_REPOSITORY ${repo_url}
      GIT_TAG        ${ARG_TAG}
      GIT_SHALLOW    TRUE
      SYSTEM         TRUE
      CMAKE_ARGS     ${_dep_cmake_args}
    )

    string(TOUPPER "${fetch_id}" upper_id)

    if(ARG_PATCH)
      set(src_dir "${FETCHCONTENT_BASE_DIR}/${fetch_id}-src")
      if(NOT EXISTS "${src_dir}")
        file(MAKE_DIRECTORY "${src_dir}")
        execute_process(
          COMMAND git clone --depth 1 --branch "${ARG_TAG}"
                  "${repo_url}" "${src_dir}"
          RESULT_VARIABLE clone_ok
          ERROR_VARIABLE  clone_err
        )
        if(NOT clone_ok EQUAL 0)
          log_fatal("import_dependency: git clone failed for ${qualified_target}\n${clone_err}")
        endif()
        set(status "From fetch -> ")
      else()
        set(status "From cache -> ")
      endif()
      set(FETCHCONTENT_SOURCE_DIR_${upper_id} "${src_dir}" CACHE INTERNAL "")
      set(${fetch_id}_SOURCE_DIR "${src_dir}")
      include("${ARG_PATCH}")
      set(suffix "  (patched)")
    else()
      if(DEFINED FETCHCONTENT_SOURCE_DIR_${upper_id}
         AND FETCHCONTENT_SOURCE_DIR_${upper_id})
        set(src_dir "${FETCHCONTENT_SOURCE_DIR_${upper_id}}")
      else()
        set(src_dir "${FETCHCONTENT_BASE_DIR}/${fetch_id}-src")
        if(EXISTS "${src_dir}")
          set(FETCHCONTENT_SOURCE_DIR_${upper_id} "${src_dir}" CACHE INTERNAL "")
        endif()
      endif()
      if(EXISTS "${src_dir}")
        set(status "From cache -> ")
      else()
        set(status "From fetch -> ")
      endif()
      set(suffix "")
    endif()

    log_status("${status}${qualified_target}${suffix}")

    # Override CMAKE_BUILD_TYPE in the current (function) scope so that
    # add_subdirectory children inherit the dependency's build type.
    #
    # Why a plain set() and not CACHE FORCE:
    #   Directory-scope variables shadow cache entries. A FORCE-set cache
    #   value is invisible to add_subdirectory when a non-cache variable
    #   (set during project()) already exists in the calling scope. Worse,
    #   FORCE-writing the cache can trigger a cmake reconfigure loop.
    set(_parent_build_type "${CMAKE_BUILD_TYPE}")
    if(_dep_build_type)
      set(CMAKE_BUILD_TYPE "${_dep_build_type}")
    endif()

    log_level_to_notice()
    FetchContent_MakeAvailable(${fetch_id})
    log_level_restore()

    # Restore parent build type
    set(CMAKE_BUILD_TYPE "${_parent_build_type}")

    set(${fetch_guard} TRUE)
  endif()

  # --- Create the CMake target ---
  __add_dependency(${ns} ${target} ${fetch_id} "${ARG_SUBDIR}")
endfunction()
