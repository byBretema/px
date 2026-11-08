# cmake -D OUT=<dir> -D REPO=<px checkout> -D FETCHED=<dir> -P bootstrap.cmake
# Makes OUT a one-commit git repo of the checkout's framework/ as it is on disk
# (uncommitted changes included), and removes FETCHED, the copy a previous run
# fetched, so the bootstrap fetches this one.
cmake_minimum_required(VERSION 3.28)

file(REMOVE_RECURSE "${OUT}" "${FETCHED}")

set(DEST "${OUT}/framework")
set(SOURCES "${REPO}/framework")
include("${CMAKE_CURRENT_LIST_DIR}/instantiate.cmake")
foreach(args "init -q" "add -A" "-c user.name=px -c user.email=px@localhost commit -q -m px")
  separate_arguments(args)
  execute_process(COMMAND git ${args} WORKING_DIRECTORY "${OUT}" COMMAND_ERROR_IS_FATAL ANY)
endforeach()
