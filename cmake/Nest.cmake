include(FetchContent)
include_guard(DIRECTORY)

set(CMAKE_POLICY_VERSION_MINIMUM 3.10)
cmake_policy(SET CMP0135 NEW)

set(CMAKE_POLICY_DEFAULT_CMP0135 NEW)

set(FETCHCONTENT_BASE_DIR "${CMAKE_SOURCE_DIR}/.nest/vendor")
set(FETCHCONTENT_QUIET ON)

add_library(Nest_AllDeps INTERFACE)

macro(__nest_add_interface_dep namespace target fetch_id subdir)
  if(NOT TARGET ${namespace}::${target})
    add_library(${namespace}_${target} INTERFACE)
    target_include_directories(${namespace}_${target} INTERFACE "${${fetch_id}_SOURCE_DIR}/${subdir}")
    add_library(${namespace}::${target} ALIAS ${namespace}_${target})
  endif()
  target_link_libraries(Nest_AllDeps INTERFACE ${namespace}::${target})
endmacro()

macro(nest_message)
  message(STATUS "[nest] · " ${ARGN})
endmacro()

message("")
nest_message("Compiler for C++ -> ${CMAKE_CXX_COMPILER_ID} ${CMAKE_CXX_COMPILER_VERSION} (${CMAKE_CXX_COMPILER})")
nest_message("Compiler for C   -> ${CMAKE_C_COMPILER_ID} ${CMAKE_C_COMPILER_VERSION} (${CMAKE_C_COMPILER})")


# ---------------------------------------------------------------------------
# __nest_detect_include_subdir — auto-detect the include subdirectory for a
#   FetchContent dependency after it has been populated.
#
#   fetch_id   : name of the FetchContent variable (the first argument passed
#              to FetchContent_Declare).  The source tree is expected at
#              ${${fetch_id}_SOURCE_DIR}.
#   out_var  : name of the output variable that receives the detected path
#              relative to the source root (e.g. "include", ".", "asio/include").
#
# Detection heuristic (tried in order):
#   1.  Root contains .h/.hpp files  →  "."
#   2a. include/src/source dir has   →  that dir
#       direct .h/.hpp files
#   2b. include/src/source dir has   →  that dir
#       subdirectories with .h/.hpp
#   3.  A top-level dir contains     →  "dir/include" if it has an include/
#       headers                          subdirectory, else "."
# ---------------------------------------------------------------------------
function(__nest_detect_include_subdir fetch_id out_var)
  set(src_dir "${${fetch_id}_SOURCE_DIR}")

  if(NOT IS_DIRECTORY "${src_dir}")
    message(WARNING "Nest: source dir '${src_dir}' not found for ${fetch_id}, defaulting to '.'")
    set(${out_var} "." PARENT_SCOPE)
    return()
  endif()

  # --- Tier 1: root contains headers directly ---
  file(GLOB root_h  "${src_dir}/*.h")
  file(GLOB root_hpp "${src_dir}/*.hpp")
  if(root_h OR root_hpp)
    set(${out_var} "." PARENT_SCOPE)
    return()
  endif()

  # --- Tier 2: conventional include/src/source dirs ---
  foreach(candidate "include" "src" "source")
    if(NOT IS_DIRECTORY "${src_dir}/${candidate}")
      continue()
    endif()

    # Tier 2a: headers directly inside (e.g. source/utf8.h)
    file(GLOB direct "${src_dir}/${candidate}/*.h" "${src_dir}/${candidate}/*.hpp")
    if(direct)
      set(${out_var} "${candidate}" PARENT_SCOPE)
      return()
    endif()

    # Tier 2b: headers in subdirs inside (e.g. include/fmt/format.h)
    file(GLOB subs "${src_dir}/${candidate}/*")
    foreach(sub ${subs})
      if(IS_DIRECTORY "${sub}")
        file(GLOB sub_h "${sub}/*.h" "${sub}/*.hpp")
        if(sub_h)
          set(${out_var} "${candidate}" PARENT_SCOPE)
          return()
        endif()
      endif()
    endforeach()
  endforeach()

  # --- Tier 3: scan top-level dirs for headers ---
  file(GLOB entries "${src_dir}/*")
  foreach(entry ${entries})
    if(IS_DIRECTORY "${entry}")
      file(GLOB_RECURSE h "${entry}/*.h" "${entry}/*.hpp")
      if(h)
        file(RELATIVE_PATH rel "${src_dir}" "${entry}")
        if(IS_DIRECTORY "${entry}/include")
          set(${out_var} "${rel}/include" PARENT_SCOPE)
        else()
          set(${out_var} "." PARENT_SCOPE)
        endif()
        return()
      endif()
    endif()
  endforeach()

  # --- Fallback ---
  message(WARNING "Nest: could not detect subdir for ${fetch_id}, defaulting to '.'")
  set(${out_var} "." PARENT_SCOPE)
endfunction()


# ---------------------------------------------------------------------------
# __nest_resolve_tag — resolve a user-supplied TAG to an actual Git ref
#   using git ls-remote.
#
#   If TAG starts with 'v' it is trusted verbatim.
#   If TAG starts with a digit (version-like), the function first tries the
#   literal tag, then prepends 'v'.  The first match wins.
#   Otherwise (branch name, commit hash, ...) TAG is used as-is.
#
#   The result (exact tag name) is returned in out_var.
# ---------------------------------------------------------------------------
function(__nest_resolve_tag repo_url user_tag out_var)
  if(user_tag MATCHES "^v")
    set(${out_var} "${user_tag}" PARENT_SCOPE)
    return()
  endif()

  if(NOT user_tag MATCHES "^[0-9]")
    set(${out_var} "${user_tag}" PARENT_SCOPE)
    return()
  endif()

  execute_process(
    COMMAND git ls-remote --tags --refs "${repo_url}" "refs/tags/${user_tag}"
    OUTPUT_VARIABLE _out
    ERROR_QUIET
    OUTPUT_STRIP_TRAILING_WHITESPACE
  )
  if(_out)
    set(${out_var} "${user_tag}" PARENT_SCOPE)
    return()
  endif()

  execute_process(
    COMMAND git ls-remote --tags --refs "${repo_url}" "refs/tags/v${user_tag}"
    OUTPUT_VARIABLE _out
    ERROR_QUIET
    OUTPUT_STRIP_TRAILING_WHITESPACE
  )
  if(_out)
    set(${out_var} "v${user_tag}" PARENT_SCOPE)
    return()
  endif()

  # Not found as a tag — pass through verbatim (may be a branch or commit hash)
  set(${out_var} "${user_tag}" PARENT_SCOPE)
endfunction()


# ---------------------------------------------------------------------------
# Nest_Import — one-shot FetchContent declaration, population, and target creation for a header-only library.
#
#   qualified_target   CMake target name in the form "namespace::target".
#                      This becomes the actual target users link against.
#
#   REPOSITORY         Full Git repository URL (https). Mutually exclusive with the shorthand keys below.
#       GITHUB             GitHub shorthand "org/repo"     →  https://github.com/org/repo.git
#       GITLAB             GitLab shorthand "org/repo"     →  https://gitlab.com/org/repo.git
#       BITBUCKET          Bitbucket shorthand "org/repo"  →  https://bitbucket.org/org/repo.git
#   TAG                Git tag, branch, or commit hash.
#   SUBDIR             (optional) Override the auto-detected include
#                      subdirectory.  Use when the heuristic fails for an
#                      unusual repository layout.
#   OPTIONS            (optional) CMake variables to set before the library's
#                      own CMake runs.  Pass as KEY=VALUE pairs.
#
# Exactly one of REPOSITORY / GITHUB / GITLAB / BITBUCKET must be given.
# Multiple calls sharing the same URL are safe — the fetch happens only
# once and the include directory is shared.
# ---------------------------------------------------------------------------
function(Nest_Import qualified_target)
  cmake_parse_arguments(ARG "" "REPOSITORY;GITHUB;GITLAB;BITBUCKET;TAG;SUBDIR;PATCH" "OPTIONS" ${ARGN})

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
    message(FATAL_ERROR "Nest_Import: one of REPOSITORY / GITHUB / GITLAB / BITBUCKET is required")
  endif()

  # --- Validate required arguments ---
  if(NOT ARG_TAG)
    message(FATAL_ERROR "Nest_Import: TAG is required")
  endif()

  # --- Parse qualified_target into namespace and target ---
  string(REPLACE "::" ";" parts "${qualified_target}")
  list(LENGTH parts len)
  if(NOT len EQUAL 2)
    message(FATAL_ERROR "Nest_Import: first arg must be ns::target, got '${qualified_target}'")
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

  # --- Fetch the dependency (only once per fetch_id) ---
  set(fetch_guard __nest_fetched_${fetch_id})
  if(NOT DEFINED ${fetch_guard})
    __nest_resolve_tag(${repo_url} "${ARG_TAG}" resolved_tag)

    FetchContent_Declare(${fetch_id}
      GIT_REPOSITORY ${repo_url}
      GIT_TAG        ${resolved_tag}
      GIT_SHALLOW    TRUE
    )

    foreach(opt ${ARG_OPTIONS})
      if(opt MATCHES "^([^=]+)=(.*)$")
        set(${CMAKE_MATCH_1} "${CMAKE_MATCH_2}" CACHE STRING "" FORCE)
      else()
        message(FATAL_ERROR "Nest_Import: OPTIONS must be KEY=VALUE, got: ${opt}")
      endif()
    endforeach()

    string(TOUPPER "${fetch_id}" upper_id)

    if(ARG_PATCH)
      set(src_dir "${FETCHCONTENT_BASE_DIR}/${fetch_id}-src")
      if(NOT EXISTS "${src_dir}")
        file(MAKE_DIRECTORY "${src_dir}")
        execute_process(
          COMMAND git clone --depth 1 --branch "${resolved_tag}"
                  "${repo_url}" "${src_dir}"
          RESULT_VARIABLE clone_ok
          ERROR_VARIABLE  clone_err
        )
        if(NOT clone_ok EQUAL 0)
          message(FATAL_ERROR
            "Nest_Import: git clone failed for ${qualified_target}\n${clone_err}")
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

    nest_message("${status}${qualified_target}${suffix}")
    set(saved_log_level "${CMAKE_MESSAGE_LOG_LEVEL}")
    set(CMAKE_MESSAGE_LOG_LEVEL "NOTICE")
    FetchContent_MakeAvailable(${fetch_id})
    if(saved_log_level)
      set(CMAKE_MESSAGE_LOG_LEVEL "${saved_log_level}")
    endif()
    set(${fetch_guard} TRUE)
  endif()

  # --- Auto-detect (or use override) the include subdirectory ---
  if(DEFINED ARG_SUBDIR)
    set(subdir "${ARG_SUBDIR}")
  else()
    __nest_detect_include_subdir(${fetch_id} subdir)
  endif()

  # --- Create the CMake target ---
  __nest_add_interface_dep(${ns} ${target} ${fetch_id} "${subdir}")
endfunction()

# ---------------------------------------------------------------------------
# Scaffolding — Nest_Exe / Nest_Lib / Nest_HLib / Nest_Link / Nest_GenerateExport
# ---------------------------------------------------------------------------

set(__nest_g_NAMESPACE "${PROJECT_NAME}" CACHE INTERNAL "Namespace for install targets")
set(__nest_g_EXPORT_TARGETS "" CACHE INTERNAL "Targets registered for export")

function(__nest_GLOB root_dir out_sources out_headers)
  file(GLOB _nest_srcs CONFIGURE_DEPENDS
    "${root_dir}/*.cpp" "${root_dir}/*.cc" "${root_dir}/*.c" "${root_dir}/*.cxx")
  file(GLOB _nest_hdrs CONFIGURE_DEPENDS
    "${root_dir}/*.hpp" "${root_dir}/*.hh" "${root_dir}/*.h" "${root_dir}/*.hxx")
  set(${out_sources} ${_nest_srcs} PARENT_SCOPE)
  set(${out_headers} ${_nest_hdrs} PARENT_SCOPE)
endfunction()


macro(Nest_Exe name)
  __nest_GLOB("${CMAKE_CURRENT_SOURCE_DIR}" _nest_srcs _nest_hdrs)
  add_executable(${name} ${_nest_srcs} ${_nest_hdrs} ${ARGN})
  if(TARGET Nest_AllDeps)
    target_link_libraries(${name} PRIVATE Nest_AllDeps)
  endif()
  target_include_directories(${name} PRIVATE
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
    $<BUILD_INTERFACE:${CMAKE_SOURCE_DIR}/vendor>)
  list(APPEND __nest_g_EXPORT_TARGETS ${name})
  set(__nest_g_EXPORT_TARGETS "${__nest_g_EXPORT_TARGETS}" CACHE INTERNAL "")
endmacro()


macro(Nest_Lib name type)
  __nest_GLOB("${CMAKE_CURRENT_SOURCE_DIR}" _nest_srcs _nest_hdrs)
  add_library(${name} ${type} ${_nest_srcs} ${_nest_hdrs} ${ARGN})
  if(TARGET Nest_AllDeps)
    target_link_libraries(${name} PUBLIC Nest_AllDeps)
  endif()
  target_include_directories(${name} PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
    $<INSTALL_INTERFACE:include/${__nest_g_NAMESPACE}>)
  target_include_directories(${name} PRIVATE
    $<BUILD_INTERFACE:${CMAKE_SOURCE_DIR}/vendor>)
  list(APPEND __nest_g_EXPORT_TARGETS ${name})
  set(__nest_g_EXPORT_TARGETS "${__nest_g_EXPORT_TARGETS}" CACHE INTERNAL "")
endmacro()


macro(Nest_HLib name)
  add_library(${name} INTERFACE)
  __nest_GLOB("${CMAKE_CURRENT_SOURCE_DIR}" _nest_srcs _nest_hdrs)
  if(_nest_hdrs)
    target_sources(${name} INTERFACE ${_nest_hdrs})
  endif()
  target_include_directories(${name} INTERFACE
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
    $<INSTALL_INTERFACE:include/${__nest_g_NAMESPACE}>)
  list(APPEND __nest_g_EXPORT_TARGETS ${name})
  set(__nest_g_EXPORT_TARGETS "${__nest_g_EXPORT_TARGETS}" CACHE INTERNAL "")
endmacro()


macro(Nest_Link target)
  target_link_libraries(${target} PRIVATE ${ARGN})
endmacro()


macro(Nest_EnableTests)
  if(PROJECT_IS_TOP_LEVEL)
    enable_testing()
  endif()
endmacro()


macro(Nest_Test name)
  __nest_GLOB("${CMAKE_CURRENT_SOURCE_DIR}" _nest_srcs _nest_hdrs)
  add_executable(${name} ${_nest_srcs} ${_nest_hdrs} ${ARGN})
  if(TARGET Nest_AllDeps)
    target_link_libraries(${name} PRIVATE Nest_AllDeps)
  endif()
  target_include_directories(${name} PRIVATE
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
    $<BUILD_INTERFACE:${CMAKE_SOURCE_DIR}/vendor>)
  add_test(NAME ${name} COMMAND ${name})
endmacro()


function(Nest_GenerateExport)
  cmake_parse_arguments(ARG "" "NAMESPACE" "DEPS" ${ARGN})

  if(ARG_NAMESPACE)
    set(__nest_g_NAMESPACE "${ARG_NAMESPACE}" CACHE INTERNAL "")
  endif()
  set(export_set "${__nest_g_NAMESPACE}-targets")

  if(NOT __nest_g_EXPORT_TARGETS)
    nest_message("No targets registered for export")
    return()
  endif()

  include(CMakePackageConfigHelpers)

  install(TARGETS ${__nest_g_EXPORT_TARGETS}
    EXPORT ${export_set}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
    INCLUDES DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})

  install(EXPORT ${export_set}
    FILE ${export_set}.cmake
    NAMESPACE ${__nest_g_NAMESPACE}::
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/${__nest_g_NAMESPACE})

  set(config_content "@PACKAGE_INIT@\n\n")
  foreach(dep ${ARG_DEPS})
    string(APPEND config_content "find_dependency(${dep})\n")
  endforeach()
  string(APPEND config_content "include(\"\${CMAKE_CURRENT_LIST_DIR}/${export_set}.cmake\")\n")
  string(APPEND config_content "set(${__nest_g_NAMESPACE}_FOUND TRUE)\n")

  set(config_in_path "${CMAKE_BINARY_DIR}/${__nest_g_NAMESPACE}Config.cmake.in")
  file(WRITE "${config_in_path}" "${config_content}")

  configure_package_config_file(
    "${config_in_path}"
    "${CMAKE_BINARY_DIR}/${__nest_g_NAMESPACE}Config.cmake"
    INSTALL_DESTINATION "${CMAKE_INSTALL_LIBDIR}/cmake/${__nest_g_NAMESPACE}")

  install(FILES "${CMAKE_BINARY_DIR}/${__nest_g_NAMESPACE}Config.cmake"
    DESTINATION "${CMAKE_INSTALL_LIBDIR}/cmake/${__nest_g_NAMESPACE}")

  if(PROJECT_VERSION)
    write_basic_package_version_file(
      "${CMAKE_BINARY_DIR}/${__nest_g_NAMESPACE}ConfigVersion.cmake"
      VERSION ${PROJECT_VERSION}
      COMPATIBILITY AnyNewerVersion)
    install(FILES "${CMAKE_BINARY_DIR}/${__nest_g_NAMESPACE}ConfigVersion.cmake"
      DESTINATION "${CMAKE_INSTALL_LIBDIR}/cmake/${__nest_g_NAMESPACE}")
  endif()

  nest_message("Export generated (${__nest_g_NAMESPACE} :: ${__nest_g_EXPORT_TARGETS})")
  message("")
endfunction()


message("")
include(${CMAKE_CURRENT_LIST_DIR}/Dependencies.cmake)
nest_message("All dependencies fetched and configured.\n            Interface target -> Nest_AllDeps")
message("")


include(${CMAKE_CURRENT_LIST_DIR}/Defaults.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/Warnings.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/Sanitizers.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/CompileCommands.cmake)
