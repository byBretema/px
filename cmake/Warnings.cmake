option(WARNINGS_AS_ERRORS "Treat compiler warnings as errors" OFF)

function(setup_warnings project_name)
  # ------------------------------------------------------------------
  # MSVC — compiler conformance flags (not warnings, but required for
  #        correct C++20 behaviour on MSVC)
  # ------------------------------------------------------------------
  set(MSVC_OPTIONS
    /Zc:preprocessor            # conforming preprocessor (two-phase name lookup)
    /utf-8                      # source + execution character set = UTF-8
  )

  # ------------------------------------------------------------------
  # MSVC — warning flags (each /wNNNN enables a warning that is
  #        off-by-default at /W4; /weNNNN makes it an error).
  # ------------------------------------------------------------------
  set(MSVC_WARNINGS
    /W4                         # warning level 4 (reasonable maximum)
    /permissive-                # strict standards conformance

    /w14242  # C4242 — conversion from 'T1' to 'T2', possible loss of data
    /w14254  # C4254 — 'operator': conversion from 'T1' to 'T2', possible loss of data
    /w14263  # C4263 — member function does not override any base class virtual
    /w14265  # C4265 — class has virtual functions but destructor is not virtual
    /w14287  # C4287 — unsigned/negative constant mismatch
    /we4289  # C4289 — nonstandard extension: loop var used outside for-scope (error)
    /w14296  # C4296 — expression is always 'value'
    /w14311  # C4311 — pointer truncation from 'T1' to 'T2'
    /w14545  # C4545 — expression before comma evaluates to function missing arg list
    /w14546  # C4546 — function call before comma missing argument list
    /w14547  # C4547 — 'op': operator before comma has no effect
    /w14549  # C4549 — 'op1': operator before comma has no effect; did you mean 'op2'?
    /w14555  # C4555 — expression has no effect; expected expression with side-effect
    /w14619  # C4619 — #pragma warning: there is no warning number 'N'
    /w14640  # C4640 — construction of local static object is not thread-safe
    /w14826  # C4826 — conversion from 'T1' to 'T2' is sign-extended
    /w14905  # C4905 — wide string literal cast to 'LPSTR'
    /w14906  # C4906 — string literal cast to 'LPWSTR'
    /w14928  # C4928 — illegal copy-initialisation; more than one implicit conversion
  )

  set(CLANG_WARNINGS
    -Wall
    -Wextra
    -Wpedantic
    -Wconversion
    -Wsign-conversion
    -Wshadow
    -Wnon-virtual-dtor
    -Wold-style-cast
    -Wcast-align
    -Wunused
    -Woverloaded-virtual
    -Wnull-dereference
    -Wformat=2
    -Wundef
    -Wdouble-promotion
    -Wimplicit-fallthrough
    -Wno-c++98-compat
    -Wno-c++98-compat-pedantic
    -Wno-float-equal
    -Wno-language-extension-token
  )

  set(GCC_WARNINGS
    ${CLANG_WARNINGS}
    -Wmisleading-indentation
    -Wduplicated-cond
    -Wduplicated-branches
    -Wlogical-op
    -Wuseless-cast
    -Wno-strict-aliasing
  )

  if(WARNINGS_AS_ERRORS)
    set(CLANG_WARNINGS ${CLANG_WARNINGS} -Werror)
    set(GCC_WARNINGS ${GCC_WARNINGS} -Werror)
    set(MSVC_WARNINGS ${MSVC_WARNINGS} /WX)
  endif()

  if(MSVC)
    target_compile_options(${project_name} PUBLIC ${MSVC_OPTIONS} ${MSVC_WARNINGS})
  elseif(CMAKE_CXX_COMPILER_ID MATCHES "Clang")
    target_compile_options(${project_name} PUBLIC ${CLANG_WARNINGS})
  elseif(CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
    target_compile_options(${project_name} PUBLIC ${GCC_WARNINGS})
  endif()
endfunction()
