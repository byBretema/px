# Hardening of own targets (PX_ENABLE_HARDENING): checks that abort on a
# memory bug (buffer overflow, smashed stack) instead of running on corrupted
# memory. The standard library's bounds checks (PX_ENABLE_STL_ASSERTIONS) are
# on in Debug only unless asked: they abort on latent bugs that seemed to work.
# MSVC needs nothing here: /GS, /DYNAMICBASE and /NXCOMPAT are its defaults.

set(__hardening_compile "")
set(__hardening_link "")
if(PX_ENABLE_HARDENING AND NOT MSVC)
  include(CheckCXXCompilerFlag)
  include(CheckLinkerFlag)
  set(CMAKE_REQUIRED_QUIET ON)
  # Probed: they depend on the compiler version and the target arch
  # (-fcf-protection x86 only, -mbranch-protection AArch64 only).
  foreach(__flag -fstack-protector-strong -fstack-clash-protection -fcf-protection=full -mbranch-protection=standard)
    string(MAKE_C_IDENTIFIER "__px_cxx${__flag}" __ok)
    check_cxx_compiler_flag(${__flag} ${__ok})
    if(${__ok})
      list(APPEND __hardening_compile ${__flag})
    endif()
  endforeach()
  # Relocations read-only after startup (ELF only).
  check_linker_flag(CXX "LINKER:-z,relro,-z,now" __px_link_relro_now)
  if(__px_link_relro_now)
    list(APPEND __hardening_link "LINKER:-z,relro,-z,now")
  endif()
  unset(CMAKE_REQUIRED_QUIET)

  # Sanitizers replace these checks (ASan intercepts the same calls; MSan
  # reports the fortified ones). Needs optimization; -U: some toolchains
  # predefine it (Ubuntu, Arch), and a redefinition warns. MinGW's needs
  # libssp linked by hand.
  if(NOT __san_flags AND NOT WIN32)
    list(APPEND __hardening_compile $<$<NOT:$<CONFIG:Debug>>:-U_FORTIFY_SOURCE;-D_FORTIFY_SOURCE=3>)
  endif()
endif()

set(__stl_assertions _GLIBCXX_ASSERTIONS _LIBCPP_HARDENING_MODE=_LIBCPP_HARDENING_MODE_FAST)

function(setup_hardening project_name)

  if(NOT PX_ENABLE_HARDENING)
    return()
  endif()

  target_compile_options(${project_name} PRIVATE ${__hardening_compile})
  target_link_options(${project_name} PRIVATE ${__hardening_link})
  if(PX_ENABLE_STL_ASSERTIONS)
    target_compile_definitions(${project_name} PRIVATE ${__stl_assertions})
  else()
    target_compile_definitions(${project_name} PRIVATE $<$<CONFIG:Debug>:${__stl_assertions}>)
  endif()

endfunction()
