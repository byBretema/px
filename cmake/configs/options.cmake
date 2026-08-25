#-------------------------------------------------------------------------------
# User options
#-------------------------------------------------------------------------------

option(USE_CCACHE           "Enable ccache build caching"          ON )
option(USE_MOLD             "Use mold linker"                      ON )
option(USE_MIMALLOC         "Use mimalloc allocator"               ON )

option(USE_COMPILE_COMMANDS "Use CompileCommands.json"             ON )

option(ENABLE_ASAN          "Enable address sanitizer"             OFF)
option(ENABLE_UBSAN         "Enable undefined behaviour sanitizer" OFF)
option(WARNINGS_AS_ERRORS   "Treat compiler warnings as errors"    OFF)
