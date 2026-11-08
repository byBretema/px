# C/C++ file extensions, shared by targets, format and dep header installs.

include_guard(DIRECTORY)

set(__source_exts cpp cc cxx c)
set(__header_exts hpp hh hxx h)

# file(GLOB_RECURSE) patterns: every extension of ARGN under each of `dirs`.
function(__ext_patterns out dirs)
  set(patterns "")
  foreach(dir IN LISTS dirs)
    foreach(ext IN LISTS ARGN)
      list(APPEND patterns "${dir}/*.${ext}")
    endforeach()
  endforeach()
  set(${out} ${patterns} PARENT_SCOPE)
endfunction()
