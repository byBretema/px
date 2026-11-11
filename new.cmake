# Makes the current dir a px project from the template of a px release:
#   cmake [-D NAME=<name>] [-D FORCE=ON] [-D PX_GIT_TAG=<tag>] -P new.cmake
# Usually through new.sh / new.ps1 (see the README), which also check the
# tools and ask before FORCE.
#
# NAME     project name and library namespace (<name>::<lib>); default: the
#          dir's name
# FORCE    ON: the dir may hold files (a .git is always fine); files named
#          like the template's are replaced
# PX_GIT_TAG         px release to start from (default: the release this
#                    script came from, else the latest v* tag)
# PX_GIT_REPOSITORY  px repo (default: the upstream one)
#
# The project then loads that release's px on its first configure, and is a
# new git repo unless it's inside one already.
cmake_minimum_required(VERSION 3.28)

# Set by the release job in the copy it publishes.
set(__release_tag "")

if(NOT DEFINED PX_GIT_REPOSITORY)
  set(PX_GIT_REPOSITORY https://github.com/byBretema/px.git)
endif()

# In script mode the current source dir is the working dir.
set(dest "${CMAKE_CURRENT_SOURCE_DIR}")
if(NOT NAME)
  cmake_path(GET dest FILENAME NAME)
endif()
# Also the namespace of the project's libs (<name>::<lib>).
if(NOT NAME MATCHES "^[A-Za-z][A-Za-z0-9_-]*$")
  message(FATAL_ERROR "NAME: a letter, then letters, digits, '_' or '-'; got '${NAME}' (pass -D NAME=<name>)")
endif()
file(GLOB existing "${dest}/*" "${dest}/.*")
list(REMOVE_ITEM existing "${dest}/.git")
if(existing AND NOT FORCE)
  message(FATAL_ERROR "${dest} isn't empty: -D FORCE=ON to go on, replacing files named like the template's")
endif()

find_program(git_exe git REQUIRED)
# GIT_TERMINAL_PROMPT=0: a wrong URL would ask for credentials and hang.
set(git ${CMAKE_COMMAND} -E env GIT_TERMINAL_PROMPT=0 "${git_exe}")

if(NOT PX_GIT_TAG AND __release_tag)
  set(PX_GIT_TAG ${__release_tag})
elseif(NOT PX_GIT_TAG)
  execute_process(COMMAND ${git} ls-remote --tags --refs "${PX_GIT_REPOSITORY}" "v*"
    OUTPUT_VARIABLE refs
    COMMAND_ERROR_IS_FATAL ANY)
  set(latest "")
  string(REGEX MATCHALL "refs/tags/v[0-9]+\\.[0-9]+\\.[0-9]+\n" tags "${refs}")
  foreach(tag IN LISTS tags)
    string(REGEX REPLACE "refs/tags/v|\n" "" version "${tag}")
    if(version VERSION_GREATER latest)
      set(latest ${version})
    endif()
  endforeach()
  if(NOT latest)
    message(FATAL_ERROR "no v<major>.<minor>.<patch> tag in ${PX_GIT_REPOSITORY}: pass PX_GIT_TAG")
  endif()
  set(PX_GIT_TAG v${latest})
endif()

# Into a temp dir in the project dir, removed afterwards: only template/ is kept.
message(STATUS "Fetching px ${PX_GIT_TAG} (${PX_GIT_REPOSITORY})")
set(tmp "${dest}/.px-new")
file(REMOVE_RECURSE "${tmp}")
execute_process(COMMAND ${git} init -q "${tmp}" COMMAND_ERROR_IS_FATAL ANY)
execute_process(COMMAND ${git} -C "${tmp}" fetch -q --depth 1 "${PX_GIT_REPOSITORY}" "${PX_GIT_TAG}"
  COMMAND_ERROR_IS_FATAL ANY)
execute_process(COMMAND ${git} -C "${tmp}" checkout -q FETCH_HEAD COMMAND_ERROR_IS_FATAL ANY)

file(COPY "${tmp}/template/" DESTINATION "${dest}")
file(REMOVE_RECURSE "${tmp}")

file(READ "${dest}/CMakeLists.txt" root)
string(REGEX REPLACE "project\\(myproj( |\\))" "project(${NAME}\\1" root "${root}")
file(WRITE "${dest}/CMakeLists.txt" "${root}")

# Not inside an existing repo (a monorepo's projects/): it already tracks the dir.
execute_process(COMMAND ${git} -C "${dest}" rev-parse --is-inside-work-tree
  RESULT_VARIABLE outside OUTPUT_QUIET ERROR_QUIET)
if(outside)
  execute_process(COMMAND ${git} init -q "${dest}" COMMAND_ERROR_IS_FATAL ANY)
endif()

message(STATUS "Created ${NAME} (px ${PX_GIT_TAG}) in ${dest}. Next:\n"
  "  just add_exe ${NAME}\n"
  "  just run ${NAME}")
