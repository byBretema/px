set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

if(NOT WIN32)
  if(EXISTS "${CMAKE_SOURCE_DIR}/compile_commands.json" AND NOT IS_SYMLINK "${CMAKE_SOURCE_DIR}/compile_commands.json")
    message(WARNING "compile_commands.json exists and is not a symlink — leaving it alone")
  else()
    file(REMOVE "${CMAKE_SOURCE_DIR}/compile_commands.json")
    file(CREATE_LINK "${CMAKE_BINARY_DIR}/compile_commands.json"
                     "${CMAKE_SOURCE_DIR}/compile_commands.json"
                     SYMBOLIC)
  endif()
else()
  file(COPY_FILE "${CMAKE_BINARY_DIR}/compile_commands.json"
                 "${CMAKE_SOURCE_DIR}/compile_commands.json"
                 ONLY_IF_DIFFERENT)
endif()
