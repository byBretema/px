# Loads px, before project(). In order:
#   1. PX_DIR (cache or env): a px checkout's framework/ dir, for px work;
#   2. an installed px (find_package);
#   3. PX_GIT_TAG of PX_GIT_REPOSITORY, fetched once into the deps dir.
# Nested in another px project, the parent's px is reused (cached px_DIR) and
# only checked against the version requested here.
#
# PX_GIT_TAG must be a tag or commit: a fetched copy is never updated.

# The px release this project is written for; also the minimum accepted.
set(__px_version 0.1.2)
if(NOT DEFINED PX_GIT_REPOSITORY)
  set(PX_GIT_REPOSITORY https://github.com/byBretema/px.git)
endif()
if(NOT DEFINED PX_GIT_TAG)
  set(PX_GIT_TAG v${__px_version})
endif()

# Top level: resolve again each configure, as PX_DIR or the tag may change.
if(CMAKE_CURRENT_SOURCE_DIR STREQUAL CMAKE_SOURCE_DIR)
  unset(px_DIR CACHE)
endif()

set(PX_DIR "$ENV{PX_DIR}" CACHE PATH "px framework dir (empty: installed or fetched)")
if(PX_DIR)
  find_package(px ${__px_version} REQUIRED CONFIG PATHS "${PX_DIR}" NO_DEFAULT_PATH)
  return()
endif()
find_package(px ${__px_version} CONFIG QUIET)
if(px_FOUND)
  return()
endif()

if(PX_DEPS_DIR)
  set(__px_deps "${PX_DEPS_DIR}")
elseif(DEFINED ENV{PX_DEPS_DIR})
  set(__px_deps "$ENV{PX_DEPS_DIR}")
else()
  set(__px_deps "${CMAKE_SOURCE_DIR}/.deps")
endif()
set(__px_src "${__px_deps}/px-${PX_GIT_TAG}")

file(MAKE_DIRECTORY "${__px_deps}")
# Build dirs configured at once share the deps dir.
file(LOCK "${__px_src}.lock" GUARD FILE TIMEOUT 600)
if(NOT EXISTS "${__px_src}/framework/pxConfig.cmake")
  message(STATUS "Fetching px ${PX_GIT_TAG} (${PX_GIT_REPOSITORY})")
  # Into a temp dir first: an interrupted fetch leaves no half copy behind.
  set(__px_tmp "${__px_src}.tmp")
  file(REMOVE_RECURSE "${__px_tmp}")
  execute_process(COMMAND git init -q "${__px_tmp}" COMMAND_ERROR_IS_FATAL ANY)
  # GIT_TERMINAL_PROMPT=0: a wrong URL would ask for credentials, hanging configure.
  execute_process(COMMAND ${CMAKE_COMMAND} -E env GIT_TERMINAL_PROMPT=0
      git -C "${__px_tmp}" fetch -q --depth 1 "${PX_GIT_REPOSITORY}" "${PX_GIT_TAG}"
    COMMAND_ERROR_IS_FATAL ANY)
  execute_process(COMMAND git -C "${__px_tmp}" checkout -q FETCH_HEAD COMMAND_ERROR_IS_FATAL ANY)
  file(REMOVE_RECURSE "${__px_src}")
  file(RENAME "${__px_tmp}" "${__px_src}")
endif()
file(LOCK "${__px_src}.lock" RELEASE)

find_package(px ${__px_version} REQUIRED CONFIG PATHS "${__px_src}/framework" NO_DEFAULT_PATH)
