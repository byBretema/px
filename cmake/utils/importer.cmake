#-------------------------------------------------------------------------------
# import_dependency(<ns>::<target> <source> TAG <ref> SUBDIR <dir> [...])
#
#   <source>         REPOSITORY <url> | GITHUB <org/repo> | GITLAB <org/repo>
#                    | BITBUCKET <org/repo>
#   TAG              tag, branch or commit
#   SUBDIR           include dir, relative to the repo root
#   OPTIONS          KEY=VALUE cache entries for the dep's own CMake
#   DEFINES          macros for px targets using the dep; the dep's own build
#                    never sees them (ABI switches go in OPTIONS)
#   PATCH            .patch/.diff or CMake script, see cmake/patches/README.md
#   BUILD_TYPE       overrides DEPS_BUILD_TYPE
#   COMPILERS        minimum versions, <CMAKE_CXX_COMPILER_ID>=<version>
#   PACKAGE          find_package name, when it isn't <ns>
#   INSTALL_HEADERS  px installs the SUBDIR headers instead of the dep's own
#                    install rules (header-only deps without usable ones)
#
# Installing: deps' install rules are often off as a subproject; turn them on
# in OPTIONS (they only run when an installed target needs the dep). Without
# usable rules, generate fails with "requires target <x> that is not in any
# export set": use INSTALL_HEADERS, or keep the dep in PRIVATE_DEPS of a
# SHARED lib.
#-------------------------------------------------------------------------------

include(FetchContent)
find_package(Git REQUIRED)

# Sources are shared across build dirs (DEPS_DIR); build trees are not.
set(FETCHCONTENT_BASE_DIR "${CMAKE_BINARY_DIR}/_deps")
set(FETCHCONTENT_QUIET ON)


function(import_dependency qualified)
  cmake_parse_arguments(ARG "INSTALL_HEADERS"
    "REPOSITORY;GITHUB;GITLAB;BITBUCKET;TAG;SUBDIR;PATCH;BUILD_TYPE;PACKAGE"
    "OPTIONS;DEFINES;COMPILERS" ${ARGN})

  string(REPLACE "::" ";" parts "${qualified}")
  list(LENGTH parts len)
  if(NOT len EQUAL 2)
    log_fatal("import_dependency: first arg must be ns::target, got '${qualified}'")
  endif()
  list(GET parts 0 ns)
  list(GET parts 1 name)
  if(NOT ARG_PACKAGE)
    set(ARG_PACKAGE ${ns})
  endif()

  set(url "${ARG_REPOSITORY}")
  foreach(host github.com gitlab.com bitbucket.org)
    string(REGEX REPLACE "\\..*" "" key "${host}")
    string(TOUPPER "${key}" key)
    if(ARG_${key})
      set(url "https://${host}/${ARG_${key}}.git")
    endif()
  endforeach()
  foreach(required url ARG_TAG ARG_SUBDIR)
    if("${${required}}" STREQUAL "")
      log_fatal("import_dependency(${qualified}): needs a source (REPOSITORY/GITHUB/GITLAB/BITBUCKET), TAG and SUBDIR")
    endif()
  endforeach()

  __check_compilers(${qualified} ${ARG_COMPILERS})
  __set_options(${ARG_OPTIONS})

  string(REGEX REPLACE "^https?://[^/]+/|\\.git$" "" fetch_id "${url}")
  string(REPLACE "/" "_" fetch_id "${fetch_id}")
  string(TOLOWER "${fetch_id}" fetch_id)
  set(src "${DEPS_DIR}/${fetch_id}-src")

  __sync_source(status ${qualified} ${ns} "${url}" "${ARG_TAG}" "${ARG_PATCH}" ${fetch_id} "${src}")
  if(ARG_PATCH)
    string(APPEND status "  (patched)")
  endif()
  log_status("${status}")

  if(ARG_OPTIONS AND NOT EXISTS "${src}/CMakeLists.txt")
    log_warning("import_dependency(${qualified}): no CMakeLists.txt, OPTIONS are ignored (use DEFINES for macros)")
  endif()
  set(build_type "${DEPS_BUILD_TYPE}")
  if(DEFINED ARG_BUILD_TYPE)
    set(build_type "${ARG_BUILD_TYPE}")
  endif()
  __build_dep(${fetch_id} "${src}" "${build_type}")

  __add_dependency(${qualified} ${ns} ${name} ${ARG_PACKAGE}
    "${src}" "${${fetch_id}_BINARY_DIR}" "${ARG_SUBDIR}" "${ARG_DEFINES}" ${ARG_INSTALL_HEADERS})
endfunction()


# px wrapper target of the imported dep `qualified`.
function(__dep_wrapper out qualified)
  string(REPLACE "::" "_" id "${qualified}")
  set(${out} __px_dep_${id} PARENT_SCOPE)
endfunction()


#-------------------------------------------------------------------------------
# Internals
#-------------------------------------------------------------------------------

function(__check_compilers qualified)
  foreach(floor IN LISTS ARGN)
    if(NOT floor MATCHES "^([A-Za-z]+)=([0-9.]+)$")
      log_fatal("import_dependency(${qualified}): COMPILERS must be ID=VERSION, got: ${floor}")
    endif()
    if(CMAKE_MATCH_1 STREQUAL CMAKE_CXX_COMPILER_ID AND CMAKE_CXX_COMPILER_VERSION VERSION_LESS CMAKE_MATCH_2)
      log_fatal("import_dependency(${qualified}): needs ${CMAKE_MATCH_1} ${CMAKE_MATCH_2}+, found ${CMAKE_CXX_COMPILER_VERSION}")
    endif()
  endforeach()
endfunction()


# CACHE FORCE: the only way to override the dep's own cache entries before its
# add_subdirectory (CMAKE_ARGS doesn't apply there).
function(__set_options)
  foreach(opt IN LISTS ARGN)
    if(NOT opt MATCHES "^([^=]+)=(.*)$")
      log_fatal("import_dependency: OPTIONS must be KEY=VALUE, got: ${opt}")
    endif()
    set(${CMAKE_MATCH_1} "${CMAKE_MATCH_2}" CACHE STRING "" FORCE)
  endforeach()
endfunction()


# Makes `src` hold `url`@`tag` + `patch`, fetching only when its stamp differs.
function(__sync_source out qualified ns url tag patch fetch_id src)
  # The URL, not just fetch_id: that drops the host (github vs gitlab org/repo).
  set(stamp "${url}@${tag}")
  if(patch)
    file(SHA1 "${patch}" patch_hash)
    string(APPEND stamp " patch:${patch_hash}")
  endif()

  # Nested px projects: a second TAG would swap sources under the first build.
  get_property(seen GLOBAL PROPERTY __px_fetched_${fetch_id})
  if(seen)
    if(NOT seen STREQUAL stamp)
      log_warning("import_dependency(${qualified}): already imported as ${seen}, ignoring ${stamp}")
    endif()
    set(${out} "Already imported -> ${qualified}" PARENT_SCOPE)
    return()
  endif()
  set_property(GLOBAL PROPERTY __px_fetched_${fetch_id} "${stamp}")

  # Build dirs configured at once share DEPS_DIR.
  file(MAKE_DIRECTORY "${DEPS_DIR}")
  file(LOCK "${DEPS_DIR}/${fetch_id}.lock" GUARD FUNCTION TIMEOUT 600 RESULT_VARIABLE lock_rc)
  if(NOT lock_rc EQUAL 0)
    log_fatal("import_dependency(${qualified}): cannot lock ${fetch_id}: ${lock_rc}")
  endif()

  set(stamp_file "${DEPS_DIR}/${fetch_id}.stamp")
  set(old "")
  if(EXISTS "${stamp_file}" AND IS_DIRECTORY "${src}")
    file(READ "${stamp_file}" old)
  endif()
  if(old STREQUAL stamp)
    __warn_if_dirty("${src}" ${qualified})
    set(${out} "From cache -> ${qualified}" PARENT_SCOPE)
    return()
  endif()

  __check_clean("${src}" ${ns})
  __fetch_source(${qualified} "${url}" "${tag}" "${patch}" ${fetch_id} "${src}")
  file(WRITE "${stamp_file}" "${stamp}")
  if(old)
    set(${out} "Updated (${old} => ${stamp}) -> ${qualified}" PARENT_SCOPE)
  else()
    set(${out} "From fetch -> ${qualified}" PARENT_SCOPE)
  endif()
endfunction()


# EXCLUDE_FROM_ALL: deps build only when linked, and their install rules run
# only when setup_export adds them.
function(__build_dep fetch_id src build_type)
  string(TOUPPER "${fetch_id}" upper_id)
  set(FETCHCONTENT_SOURCE_DIR_${upper_id} "${src}")
  FetchContent_Declare(${fetch_id} SOURCE_DIR "${src}" SYSTEM EXCLUDE_FROM_ALL)

  # Plain set(), not CACHE FORCE: the directory var set by project() would
  # shadow it, and forcing the cache can loop reconfigures.
  if(build_type AND NOT __multi_config)
    set(CMAKE_BUILD_TYPE "${build_type}")
  endif()
  # CMake 4 rejects cmake_minimum_required() below 3.5.
  set(CMAKE_POLICY_VERSION_MINIMUM 3.10)

  log_level_to_notice()
  FetchContent_MakeAvailable(${fetch_id})
  log_level_restore()
  set(${fetch_id}_BINARY_DIR "${${fetch_id}_BINARY_DIR}" PARENT_SCOPE)
endfunction()


# Wrapper target (__dep_wrapper) for make_* DEPS: SUBDIR include, DEFINES and
# the dep's own target, if any. PX_DEP_* tell setup_export how to install it.
function(__add_dependency qualified ns name package src bin subdir defines install_headers)
  __dep_wrapper(wrapper ${qualified})
  if(TARGET ${wrapper})
    return()
  endif()

  set(real "")
  foreach(candidate ${qualified} ${name} ${ns}_${name} ${package}::${package} ${package})
    if(TARGET ${candidate})
      set(real ${candidate})
      break()
    endif()
  endforeach()

  # REAL_PATH: a symlinked include dir (asio) would install as the link.
  file(REAL_PATH "${src}/${subdir}" headers)
  string(REPLACE "__px_" "" export_name ${wrapper})
  add_library(${wrapper} INTERFACE)
  set_target_properties(${wrapper} PROPERTIES
    EXPORT_NAME ${export_name}
    PX_DEP_NAME ${qualified}
    PX_DEP_HEADERS "${headers}")
  # SYSTEM: FetchContent's SYSTEM doesn't cover a target in our directory.
  target_include_directories(${wrapper} SYSTEM INTERFACE "$<BUILD_INTERFACE:${headers}>")
  target_compile_definitions(${wrapper} INTERFACE ${defines})

  if(real AND NOT install_headers)
    target_link_libraries(${wrapper} INTERFACE ${real})
    get_target_property(aliased ${real} ALIASED_TARGET)
    if(aliased)
      set(real ${aliased})
    endif()
    __package_version(version "${bin}" ${package})
    get_target_property(type ${real} TYPE)
    set_target_properties(${wrapper} PROPERTIES
      PX_DEP_REAL ${real}
      PX_DEP_PACKAGE "${package}"
      PX_DEP_VERSION "${version}"
      PX_DEP_TYPE ${type}
      PX_DEP_INSTALL_SCRIPT "${bin}/cmake_install.cmake")
    set_property(GLOBAL PROPERTY __px_dep_of_${real} ${wrapper})
  else()
    if(real)
      target_link_libraries(${wrapper} INTERFACE $<BUILD_INTERFACE:${real}>)
    endif()
    target_include_directories(${wrapper} SYSTEM INTERFACE
      "$<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>")
  endif()

  if(NOT TARGET ${qualified})
    add_library(${qualified} ALIAS ${wrapper})
  endif()
endfunction()


# From the dep's generated version file: fmt's project() has no VERSION.
function(__package_version out bin package)
  string(TOLOWER "${package}" lower)
  set(names "${package}ConfigVersion.cmake" "${package}Config-version.cmake" "${lower}-config-version.cmake")
  file(GLOB_RECURSE candidates "${bin}/*ersion.cmake")
  set(version "")
  foreach(file IN LISTS candidates)
    cmake_path(GET file FILENAME filename)
    if(filename IN_LIST names)
      file(STRINGS "${file}" line REGEX "set\\(PACKAGE_VERSION \"[0-9]" LIMIT_COUNT 1)
      string(REGEX MATCH "\"([0-9][^\"]*)\"" match "${line}")
      set(version "${CMAKE_MATCH_1}")
      break()
    endif()
  endforeach()
  set(${out} "${version}" PARENT_SCOPE)
endfunction()


# Built in `dir`.tmp and swapped in when complete: a failed fetch never leaves
# a half-made `dir`. `git fetch <ref>` takes tags, branches and SHAs alike.
# The upstream commit is tagged px-base, so `git diff px-base` yields a patch.
function(__fetch_source qualified url ref patch fetch_id dir)
  set(tmp "${dir}.tmp")
  file(REMOVE_RECURSE "${tmp}")
  file(MAKE_DIRECTORY "${tmp}")
  __git("${tmp}" init -q)
  __git("${tmp}" remote add origin "${url}")
  __fetch_ref(${qualified} "${url}" "${ref}" "${tmp}")
  __git("${tmp}" checkout -q FETCH_HEAD)
  __git("${tmp}" tag px-base)

  if(patch MATCHES "\\.(patch|diff)$")
    __git("${tmp}" apply --whitespace=nowarn "${patch}")
  elseif(patch)
    set(${fetch_id}_SOURCE_DIR "${tmp}")
    include("${patch}")
  endif()
  if(patch)
    # Committed, so the patched checkout counts as clean.
    cmake_path(GET patch FILENAME patch_name)
    __git("${tmp}" add -A)
    __git("${tmp}" -c user.name=px -c user.email=px@localhost
      commit -q --allow-empty -m "px: ${patch_name}")
  endif()

  file(REMOVE_RECURSE "${dir}")
  file(RENAME "${tmp}" "${dir}")
endfunction()


# GIT_TERMINAL_PROMPT=0: a wrong GitHub URL asks for credentials, hanging
# configure. ls-remote tells an unreachable repo from a missing ref.
function(__fetch_ref qualified url ref dir)
  set(git ${CMAKE_COMMAND} -E env GIT_TERMINAL_PROMPT=0 "${GIT_EXECUTABLE}")
  execute_process(COMMAND ${git} fetch -q --depth 1 origin "${ref}"
    WORKING_DIRECTORY "${dir}"
    RESULT_VARIABLE rc
    ERROR_VARIABLE err)
  if(rc EQUAL 0)
    return()
  endif()
  file(REMOVE_RECURSE "${dir}")

  execute_process(COMMAND ${git} ls-remote -q "${url}" HEAD
    RESULT_VARIABLE unreachable
    OUTPUT_QUIET ERROR_QUIET)
  if(unreachable)
    set(why "cannot reach ${url}: check the URL/repo name and the network (private repos need git credentials)")
  else()
    set(why "TAG '${ref}' not found in ${url}: check the tag, branch or commit name")
  endif()
  string(STRIP "${err}" err)
  string(REGEX REPLACE "([^\n]+)" "    \\1" err "${err}")
  log_fatal("import_dependency(${qualified}): ${why}\n  git said:\n${err}")
endfunction()


# On failure deletes `dir` (always a .tmp checkout).
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


# Warning only: editing a dep to debug it is legit. Untracked files skipped:
# harmless to builds, and the slow part of `git status`.
function(__warn_if_dirty dir qualified)
  execute_process(COMMAND "${GIT_EXECUTABLE}" status --porcelain --untracked-files=no
    WORKING_DIRECTORY "${dir}"
    OUTPUT_VARIABLE changes
    OUTPUT_STRIP_TRAILING_WHITESPACE)
  if(changes)
    string(REGEX REPLACE "([^\n]+)" "    \\1" changes "${changes}")
    log_warning("import_dependency(${qualified}): sources in ${dir} differ from the fetched commit:\n${changes}")
  endif()
endfunction()


function(__check_clean dir ns)
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
  if(NOT changes)
    return()
  endif()

  # Checkouts older than px-base: diff against HEAD.
  execute_process(COMMAND "${GIT_EXECUTABLE}" rev-parse -q --verify px-base
    WORKING_DIRECTORY "${dir}"
    RESULT_VARIABLE no_base
    OUTPUT_QUIET)
  set(base px-base)
  if(no_base)
    set(base HEAD)
  endif()
  set(patch_file "${__base_dir}/patches/${ns}.patch")
  # message() prints indented lines verbatim and rewraps the rest.
  string(REGEX REPLACE "([^\n]+)\n" "    \\1\n" changes "${changes}")
  log_fatal("import_dependency: local changes in ${dir} would be lost by re-fetch.\n"
    "${changes}"
    "  Keep them as a patch (full diff from upstream, includes any current PATCH):\n"
    "    git -C \"${dir}\" add -A\n"
    "    git -C \"${dir}\" diff --cached --binary ${base} > \"${patch_file}\"\n"
    "  and point this dep's PATCH at it in cmake/deps.cmake (replaces any existing PATCH).\n"
    "  Then (or to discard them) remove the checkout:\n"
    "    cmake -E rm -rf \"${dir}\"")
endfunction()
