#-------------------------------------------------------------------------------
# Package: CPack over the install rules of setup_export (top-level only)
#
#   cmake --build --preset <preset> --target package          ->  <build>/packages/
#   cmake --build --preset <preset> --target package_source
#-------------------------------------------------------------------------------

# Name, version and description come from the top-level project().
# `cpack -G <gen>` (DEB, RPM, NSIS...) overrides the generator.
if(NOT CPACK_GENERATOR)
  if(WIN32)
    set(CPACK_GENERATOR ZIP)
  else()
    set(CPACK_GENERATOR TGZ)
  endif()
endif()
set(CPACK_SOURCE_GENERATOR "${CPACK_GENERATOR}")
set(CPACK_PACKAGE_DIRECTORY "${CMAKE_BINARY_DIR}/packages")

# Written to CPackConfig.cmake as is: regexes below need no double escaping.
set(CPACK_VERBATIM_VARIABLES ON)

# Source packages: tracked sources only, not build output, fetched deps or caches.
set(CPACK_SOURCE_IGNORE_FILES
  "/\\.git(/|$)"  # a dir, or a file in git worktrees
  "/\\.build/" "/\\.install/"
  "/\\.deps/"
  "/\\.cache/"
  "/build/"
  "/compile_commands\\.json$"
  "/\\.claude/")

include(CPack)
