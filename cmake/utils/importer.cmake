#-------------------------------------------------------------------------------
# Importer utils
#-------------------------------------------------------------------------------

include(FetchContent)
find_package(Git REQUIRED)

# Sources live in DEPS_DIR (shared across build dirs, managed below);
# FetchContent state and build trees stay per build dir. Nested
# FetchContent calls made by deps themselves also land here.
set(FETCHCONTENT_BASE_DIR "${CMAKE_BINARY_DIR}/_deps")
set(FETCHCONTENT_QUIET ON)

# Shared by nested px projects: the first one creates it.
if(NOT TARGET all_dependencies)
  add_library(all_dependencies INTERFACE)
endif()

# Fetches `ref` of `url` into `dir`, applying `patch` if given: a .patch/.diff
# file goes through `git apply`, anything else is included as a CMake script.
# The fetched commit is tagged `px-base` so `git diff px-base` yields a patch.
# Works in `dir`.tmp and swaps it in only when complete, so an interrupted or
# failed fetch never leaves a half-made `dir`. Shallow `git fetch <ref>` works
# for tags, branches and commit SHAs, unlike `git clone --branch`.
# Submodules are not fetched (current deps only use them for docs/tests).
function(__fetch_source url ref patch fetch_id dir)
  set(tmp "${dir}.tmp")
  file(REMOVE_RECURSE "${tmp}")
  file(MAKE_DIRECTORY "${tmp}")
  foreach(args
      "init;-q"
      "remote;add;origin;${url}"
      "fetch;-q;--depth;1;origin;${ref}"
      "checkout;-q;FETCH_HEAD"
      "tag;px-base")
    __git("${tmp}" ${args})
  endforeach()

  if(patch MATCHES "\\.(patch|diff)$")
    __git("${tmp}" apply --whitespace=nowarn "${patch}")
  elseif(patch)
    set(${fetch_id}_SOURCE_DIR "${tmp}")
    include("${patch}")
  endif()
  if(patch)
    # Commit so the patch result counts as clean in __check_clean.
    __git("${tmp}" add -A)
    get_filename_component(patch_name "${patch}" NAME)
    __git("${tmp}" -c user.name=px -c user.email=px@localhost
      commit -q --allow-empty -m "px: ${patch_name}")
  endif()

  file(REMOVE_RECURSE "${dir}")
  file(RENAME "${tmp}" "${dir}")
endfunction()

# Runs git in `dir`; on failure deletes `dir` (always a .tmp checkout).
function(__git dir)
  execute_process(COMMAND "${GIT_EXECUTABLE}" ${ARGN}
    WORKING_DIRECTORY "${dir}"
    RESULT_VARIABLE rc
    ERROR_VARIABLE err)
  if(NOT rc EQUAL 0)
    file(REMOVE_RECURSE "${dir}")
    string(JOIN " " cmd ${ARGN})
    log_fatal("import_dependency: `git ${cmd}` failed in ${dir}\n${err}")
  endif()
endfunction()

# Cached sources are trusted by stamp; this flags tracked files changed or
# deleted since (a stray edit, a partial rm). Warning only: editing a dep to
# debug it is legit. Untracked files are skipped: they don't break builds,
# and walking for them is the slow part of `git status`.
function(__warn_if_dirty dir name)
  execute_process(COMMAND "${GIT_EXECUTABLE}" status --porcelain --untracked-files=no
    WORKING_DIRECTORY "${dir}"
    OUTPUT_VARIABLE changes
    OUTPUT_STRIP_TRAILING_WHITESPACE)
  if(changes)
    string(REGEX REPLACE "([^\n]+)" "    \\1" changes "${changes}")
    log_warning("import_dependency: ${name} sources in ${dir} differ from the fetched commit:\n${changes}")
  endif()
endfunction()

# Refuses to replace a source dir holding changes a re-fetch would destroy.
function(__check_clean dir name)
  if(NOT IS_DIRECTORY "${dir}")
    return()
  endif()
  # Without its own .git, `git status` would walk up into the parent repo.
  if(NOT IS_DIRECTORY "${dir}/.git")
    log_fatal("import_dependency: ${dir} is not a git checkout, delete it to re-fetch.")
  endif()
  execute_process(COMMAND "${GIT_EXECUTABLE}" status --porcelain
    WORKING_DIRECTORY "${dir}"
    OUTPUT_VARIABLE changes)
  if(changes)
    # Checkouts fetched before px-base existed: diff against HEAD instead.
    execute_process(COMMAND "${GIT_EXECUTABLE}" rev-parse -q --verify px-base
      WORKING_DIRECTORY "${dir}"
      RESULT_VARIABLE no_base
      OUTPUT_QUIET)
    set(base px-base)
    if(no_base)
      set(base HEAD)
    endif()
    set(patch_file "${__base_dir}/patches/${name}.patch")
    # Indented lines are printed verbatim by message(); the rest gets rewrapped.
    string(REGEX REPLACE "([^\n]+)\n" "    \\1\n" changes "${changes}")
    log_fatal("import_dependency: local changes in ${dir} would be lost by re-fetch.\n"
      "${changes}"
      "  Keep them as a patch (full diff from upstream, includes any current PATCH):\n"
      "    git -C \"${dir}\" add -A\n"
      "    git -C \"${dir}\" diff --cached --binary ${base} > \"${patch_file}\"\n"
      "  and point this dep's PATCH at it in cmake/deps.cmake (replaces any existing PATCH).\n"
      "  Then (or to discard them) remove the checkout:\n"
      "    cmake -E rm -rf \"${dir}\"")
  endif()
endfunction()

macro(__add_dependency namespace target fetch_id subdir defines)
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
    # SYSTEM: this wrapper lives in the caller's directory, so FetchContent's
    # SYSTEM does not cover it; without it dep headers trip our warnings.
    target_include_directories(${namespace}_${target} SYSTEM INTERFACE
      "${${fetch_id}_SOURCE_DIR}/${subdir}")

    # INTERFACE targets too: they may carry definitions, features, deps.
    if(_real_target)
      target_link_libraries(${namespace}_${target} INTERFACE ${_real_target})
    endif()

    add_library(${namespace}::${target} ALIAS ${namespace}_${target})
  else()
    set(_real_target ${namespace}::${target})
  endif()

  # Compiled deps are not installed; setup_export warns about them.
  if(_real_target)
    get_target_property(_type ${_real_target} TYPE)
    if(NOT _type STREQUAL "INTERFACE_LIBRARY")
      set_property(GLOBAL APPEND PROPERTY __px_compiled_deps ${namespace}::${target})
    endif()
  endif()

  # Macro parameter, not a variable: test its expanded text.
  # On all_dependencies, not the dep's target: px owns it, so the defines
  # never leak to anything else linking the dep.
  if(NOT "${defines}" STREQUAL "")
    target_compile_definitions(all_dependencies INTERFACE ${defines})
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
#   PATCH              (optional) Absolute path of a .patch/.diff (git apply) or
#                      a CMake script (included with ${<fetch_id>_SOURCE_DIR}
#                      set), run after a fresh fetch. See cmake/patches/README.md.
#   OPTIONS            (optional) CMake variables to set before the library's
#                      own CMake runs.  Pass as KEY=VALUE pairs.
#   DEFINES            (optional) Preprocessor definitions for px targets
#                      using the dep (e.g. config macros of header-only libs).
#                      Consumer side only: the dep's own build never sees
#                      them, so ABI-affecting macros of compiled deps belong
#                      in OPTIONS (the dep's own CMake switches) instead.
#
# Exactly one of REPOSITORY / GITHUB / GITLAB / BITBUCKET must be given.
# Sources are re-fetched whenever TAG or the PATCH file content changes.
# Multiple calls sharing the same URL are safe — the fetch happens only
# once and the include directory is shared.
#-------------------------------------------------------------------------------
function(import_dependency qualified_target)
  cmake_parse_arguments(ARG "" "REPOSITORY;GITHUB;GITLAB;BITBUCKET;TAG;SUBDIR;PATCH;BUILD_TYPE" "OPTIONS;DEFINES" ${ARGN})

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

  # --- Source: reuse if fetched with the same stamp, else fetch ---
  set(src_dir "${DEPS_DIR}/${fetch_id}-src")
  set(stamp_file "${DEPS_DIR}/${fetch_id}.stamp")
  # URL included: fetch_id drops the host, so github/gitlab org/repo collide.
  set(stamp "${repo_url}@${ARG_TAG}")
  if(ARG_PATCH)
    file(SHA1 "${ARG_PATCH}" patch_hash)
    string(APPEND stamp " patch:${patch_hash}")
  endif()

  # Already imported in this configure (nested px projects): re-fetching a
  # different TAG would swap sources under the first importer's build.
  get_property(seen_stamp GLOBAL PROPERTY __px_dep_${fetch_id})
  if(seen_stamp)
    set(status "Already imported -> ")
    if(NOT "${seen_stamp}" STREQUAL "${stamp}")
      log_warning("import_dependency: ${qualified_target} already imported as ${seen_stamp}, ignoring ${stamp}")
    endif()
  else()
    set_property(GLOBAL PROPERTY __px_dep_${fetch_id} "${stamp}")

    # Build dirs share DEPS_DIR; serialize check-and-fetch across configures.
    file(MAKE_DIRECTORY "${DEPS_DIR}")
    file(LOCK "${DEPS_DIR}/${fetch_id}.lock" GUARD FUNCTION TIMEOUT 600 RESULT_VARIABLE lock_rc)
    if(NOT lock_rc EQUAL 0)
      log_fatal("import_dependency: cannot lock ${fetch_id}: ${lock_rc}")
    endif()

    set(old_stamp "")
    if(EXISTS "${stamp_file}" AND IS_DIRECTORY "${src_dir}")
      file(READ "${stamp_file}" old_stamp)
    endif()

    if("${old_stamp}" STREQUAL "${stamp}")
      set(status "From cache -> ")
      __warn_if_dirty("${src_dir}" "${qualified_target}")
    else()
      if(old_stamp)
        set(status "Updated (${old_stamp} => ${stamp}) -> ")
      else()
        set(status "From fetch -> ")
      endif()
      __check_clean("${src_dir}" "${ns}")
      __fetch_source("${repo_url}" "${ARG_TAG}" "${ARG_PATCH}" "${fetch_id}" "${src_dir}")
      file(WRITE "${stamp_file}" "${stamp}")
    endif()

    file(LOCK "${DEPS_DIR}/${fetch_id}.lock" RELEASE)
  endif()

  set(suffix "")
  if(ARG_PATCH)
    set(suffix "  (patched)")
  endif()
  log_status("${status}${qualified_target}${suffix}")

  # Source override: FetchContent skips its own download and only runs
  # add_subdirectory (when the dep has a CMakeLists.txt).
  string(TOUPPER "${fetch_id}" upper_id)
  set(FETCHCONTENT_SOURCE_DIR_${upper_id} "${src_dir}")
  # EXCLUDE_FROM_ALL: deps build only when linked, and their install() rules
  # stay out of `cmake --install`.
  FetchContent_Declare(${fetch_id} SOURCE_DIR "${src_dir}" SYSTEM EXCLUDE_FROM_ALL)

  set(_dep_build_type "${DEPS_BUILD_TYPE}")
  if(DEFINED ARG_BUILD_TYPE)
    set(_dep_build_type "${ARG_BUILD_TYPE}")
  endif()

  # Override CMAKE_BUILD_TYPE in the current (function) scope so that
  # add_subdirectory children inherit the dependency's build type.
  #
  # Why a plain set() and not CACHE FORCE:
  #   Directory-scope variables shadow cache entries. A FORCE-set cache
  #   value is invisible to add_subdirectory when a non-cache variable
  #   (set during project()) already exists in the calling scope. Worse,
  #   FORCE-writing the cache can trigger a cmake reconfigure loop.
  # Multi-config generators build deps with the selected config instead.
  if(_dep_build_type AND NOT __multi_config)
    set(CMAKE_BUILD_TYPE "${_dep_build_type}")
  endif()

  log_level_to_notice()
  set(CMAKE_POLICY_VERSION_MINIMUM 3.10)
  FetchContent_MakeAvailable(${fetch_id})
  log_level_restore()

  # --- Create the CMake target ---
  # OPTIONS only reach a dep through its own CMakeLists.txt.
  if(ARG_OPTIONS AND NOT EXISTS "${src_dir}/CMakeLists.txt")
    log_warning("import_dependency: ${qualified_target} has no CMakeLists.txt, so OPTIONS are ignored (use DEFINES for macros)")
  endif()

  __add_dependency(${ns} ${target} ${fetch_id} "${ARG_SUBDIR}" "${ARG_DEFINES}")
endfunction()
