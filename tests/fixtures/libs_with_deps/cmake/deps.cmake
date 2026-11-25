include_guard(DIRECTORY)

import_dependency(fmt::fmt
  GITHUB    fmtlib/fmt
  TAG       11.1.4
  SUBDIR    include
  OPTIONS   FMT_INSTALL=ON
            FMT_TEST=OFF
            FMT_DOC=OFF
            FMT_DEBUG_POSTFIX=
)

import_dependency(utfcpp::utfcpp
  GITHUB    nemtrif/utfcpp
  TAG       v4.0.6
  SUBDIR    source
  PACKAGE   utf8cpp
  PATCH     ${CMAKE_CURRENT_LIST_DIR}/patches/utfcpp.cmake
)

import_dependency(argparse::argparse
  GITHUB    p-ranav/argparse
  TAG       v3.2
  SUBDIR    include
  PATCH     ${CMAKE_CURRENT_LIST_DIR}/patches/argparse.patch
  OPTIONS   ARGPARSE_INSTALL=ON
)
