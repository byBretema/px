#-------------------------------------------------------------------------------
# Compile Commands
#-------------------------------------------------------------------------------

if(USE_COMPILE_COMMANDS)
  set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
endif()

if(CMAKE_EXPORT_COMPILE_COMMANDS)
  file(COPY_FILE "${CMAKE_BINARY_DIR}/compile_commands.json"
       "${CMAKE_SOURCE_DIR}/compile_commands.json" ONLY_IF_DIFFERENT)
endif()
