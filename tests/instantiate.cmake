# cmake -D DEST=<dir> -D "SOURCES=<dir>;..." -P instantiate.cmake
# Copies each source's git-visible files (tracked or new, not ignored) into
# DEST, later sources over earlier ones: a project made from the template, as
# a user would. Unchanged files keep their timestamps, so rebuilds stay warm.
cmake_minimum_required(VERSION 3.28)

foreach(src IN LISTS SOURCES)
  execute_process(
    COMMAND git ls-files --cached --others --exclude-standard
    WORKING_DIRECTORY "${src}"
    OUTPUT_VARIABLE files
    COMMAND_ERROR_IS_FATAL ANY)
  string(REPLACE "\n" ";" files "${files}")
  foreach(file IN LISTS files)
    if(file AND EXISTS "${src}/${file}")
      cmake_path(GET file PARENT_PATH dir)
      file(MAKE_DIRECTORY "${DEST}/${dir}")
      file(COPY_FILE "${src}/${file}" "${DEST}/${file}" ONLY_IF_DIFFERENT)
    endif()
  endforeach()
endforeach()
