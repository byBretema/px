# CPack over setup_export's install rules: targets package, package_source.
if(NOT CPACK_GENERATOR)
  if(WIN32)
    set(CPACK_GENERATOR ZIP)
  else()
    set(CPACK_GENERATOR TGZ)
  endif()
endif()
set(CPACK_SOURCE_GENERATOR "${CPACK_GENERATOR}")
set(CPACK_PACKAGE_DIRECTORY "${CMAKE_BINARY_DIR}/packages")

# Regexes below need no double escaping.
set(CPACK_VERBATIM_VARIABLES ON)

set(CPACK_SOURCE_IGNORE_FILES
  "/\\.git(/|$)"  # a dir, or a file in git worktrees
  "/\\.build/" "/\\.install/"
  "/\\.deps/"
  "/\\.cache/"
  "/build/"
  "/compile_commands\\.json$"
  "/\\.claude/")

include(CPack)
