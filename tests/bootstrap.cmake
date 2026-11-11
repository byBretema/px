# cmake -D OUT=<dir> -D REPO=<px checkout> -D FETCHED=<dir> -P bootstrap.cmake
# Makes OUT a one-commit git repo of the checkout's framework/ and template/
# as they are on disk (uncommitted changes included), tagged v<px version>,
# and removes FETCHED, the copy a previous run fetched, so the bootstrap
# fetches this one.
cmake_minimum_required(VERSION 3.28)

file(REMOVE_RECURSE "${OUT}" "${FETCHED}")

foreach(dir framework template)
  set(DEST "${OUT}/${dir}")
  set(SOURCES "${REPO}/${dir}")
  include("${CMAKE_CURRENT_LIST_DIR}/instantiate.cmake")
endforeach()
include("${REPO}/framework/version.cmake")
foreach(args "init -q" "add -A" "-c user.name=px -c user.email=px@localhost commit -q -m px" "tag v${PX_VERSION}")
  separate_arguments(args)
  execute_process(COMMAND git ${args} WORKING_DIRECTORY "${OUT}" COMMAND_ERROR_IS_FATAL ANY)
endforeach()
