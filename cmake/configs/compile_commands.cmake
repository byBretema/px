# compile_commands.json, copied to the source root.

if(USE_COMPILE_COMMANDS)
  set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
endif()

# A build step: the file is written at generate time, after configure. The
# stamp is the output, as CMAKE_DISABLE_SOURCE_CHANGES forbids outputs in the source tree.
if(CMAKE_EXPORT_COMPILE_COMMANDS AND CMAKE_GENERATOR MATCHES "Ninja|Makefiles" AND PROJECT_IS_TOP_LEVEL)
  set(__cc_src "${CMAKE_BINARY_DIR}/compile_commands.json")
  set(__cc_stamp "${CMAKE_BINARY_DIR}/compile_commands.stamp")
  add_custom_command(OUTPUT "${__cc_stamp}"
    COMMAND ${CMAKE_COMMAND} -E copy "${__cc_src}" "${CMAKE_SOURCE_DIR}/compile_commands.json"
    COMMAND ${CMAKE_COMMAND} -E touch "${__cc_stamp}"
    DEPENDS "${__cc_src}"
    COMMENT "Copying compile_commands.json to source root")
  add_custom_target(compile_commands ALL DEPENDS "${__cc_stamp}")
endif()
