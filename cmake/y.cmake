# EntryPoint

include_guard(DIRECTORY)
include(${CMAKE_CURRENT_LIST_DIR}/Logger.cmake)

include(${CMAKE_CURRENT_LIST_DIR}/Dependencies.cmake)

include(${CMAKE_CURRENT_LIST_DIR}/Project.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/Scaffolding.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/Defaults.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/Warnings.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/Sanitizers.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/CompileCommands.cmake)
