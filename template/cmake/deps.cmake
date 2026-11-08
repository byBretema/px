# Third-party dependencies: one import_dependency() block each, then list them
# in a target's DEPS. All keywords: px docs/dependencies.md.
#
# import_dependency(fmt::fmt
#   GITHUB    fmtlib/fmt
#   TAG       11.1.4
#   SUBDIR    include
#   OPTIONS   FMT_INSTALL=ON FMT_TEST=OFF FMT_DOC=OFF FMT_DEBUG_POSTFIX=
# )
#
# System libraries (Qt, Boost): find_package(Qt6 REQUIRED COMPONENTS Core),
# then setup_export(DEPS Qt6) if installed libs use them.

include_guard(DIRECTORY)
