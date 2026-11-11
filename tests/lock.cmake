# cmake -D MODE=repo|check -D DIR=<dir> -P lock.cmake
# repo: makes DIR/repo, a git repo whose tag v1 is one commit past the commit
# DIR/deps.lock holds. check: the configure kept that commit in the lock.
cmake_minimum_required(VERSION 3.28)

set(repo "${DIR}/repo")

function(git)
  execute_process(COMMAND git -c user.name=px -c user.email=px@localhost ${ARGN}
    WORKING_DIRECTORY "${repo}"
    OUTPUT_VARIABLE out
    OUTPUT_STRIP_TRAILING_WHITESPACE
    COMMAND_ERROR_IS_FATAL ANY)
  set(out "${out}" PARENT_SCOPE)
endfunction()

if(MODE STREQUAL "repo")
  file(REMOVE_RECURSE "${repo}")
  file(MAKE_DIRECTORY "${repo}")
  git(init -q)
  foreach(value 1 2)
    file(WRITE "${repo}/value.hpp" "#define LOCKED_VALUE ${value}\n")
    git(add -A)
    git(commit -q -m "value ${value}")
    if(value EQUAL 1)
      git(rev-parse HEAD)
      set(locked "${out}")
    endif()
  endforeach()
  git(tag v1)
  file(WRITE "${DIR}/deps.lock" "locked::dep ${repo}@v1 ${locked}\n")
  file(WRITE "${DIR}/locked_commit" "${locked}")
else()
  file(READ "${DIR}/locked_commit" locked)
  file(STRINGS "${DIR}/deps.lock" lines)
  if(NOT "locked::dep ${repo}@v1 ${locked}" IN_LIST lines)
    message(FATAL_ERROR "deps.lock lost commit ${locked}:\n${lines}")
  endif()
endif()
