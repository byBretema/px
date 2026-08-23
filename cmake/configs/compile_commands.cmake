#-------------------------------------------------------------------------------
# Compile Commands
#-------------------------------------------------------------------------------

if(USE_COMPILE_COMMANDS AND NOT DEFINED CMAKE_EXPORT_COMPILE_COMMANDS)
  set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
endif()

if(CMAKE_EXPORT_COMPILE_COMMANDS)
  if(NOT WIN32)
    if(EXISTS "${CMAKE_SOURCE_DIR}/compile_commands.json" AND NOT IS_SYMLINK "${CMAKE_SOURCE_DIR}/compile_commands.json")
      log_warning("Not symlink compile_commands.json found.")
    else()
      file(REMOVE "${CMAKE_SOURCE_DIR}/compile_commands.json")
      file(CREATE_LINK "${CMAKE_BINARY_DIR}/compile_commands.json" "${CMAKE_SOURCE_DIR}/compile_commands.json" SYMBOLIC)
    endif()
  else()
    file(COPY_FILE "${CMAKE_BINARY_DIR}/compile_commands.json" "${CMAKE_SOURCE_DIR}/compile_commands.json" ONLY_IF_DIFFERENT)
  endif()
endif()
