# Settings that also reach deps (included before them).

include(GNUInstallDirs)

# Static deps linkable into shared libs.
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# DLLs next to exes on Windows. A parent project's choice wins.
if(NOT CMAKE_RUNTIME_OUTPUT_DIRECTORY)
  set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin")
  set(CMAKE_LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib")
  set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib")
endif()

# Clang's ASan on Windows rejects the debug CRT (/MDd, /MTd), and every
# object must use the same CRT: the release one for the whole tree, deps too.
if(PX_ENABLE_ASAN AND CMAKE_CXX_COMPILER_ID STREQUAL "Clang" AND CMAKE_CXX_SIMULATE_ID STREQUAL "MSVC")
  if(NOT CMAKE_MSVC_RUNTIME_LIBRARY OR CMAKE_MSVC_RUNTIME_LIBRARY MATCHES "DLL")
    set(CMAKE_MSVC_RUNTIME_LIBRARY MultiThreadedDLL)
  else()
    set(CMAKE_MSVC_RUNTIME_LIBRARY MultiThreaded)
  endif()
  log_status("CRT              -> ${CMAKE_MSVC_RUNTIME_LIBRARY} (Clang ASan rejects the debug CRT)")
endif()
