# Sanitizers: PX_ENABLE_ASAN, PX_ENABLE_UBSAN, PX_ENABLE_TSAN, PX_ENABLE_MSAN,
# PX_ENABLE_LSAN. Only own targets are instrumented: deps, and so races or
# uninitialized memory inside them, are not (MSan reports false positives
# for whatever uninstrumented code initializes).

set(__san_flags "")
foreach(__san ASAN=address UBSAN=undefined TSAN=thread MSAN=memory LSAN=leak)
  string(REPLACE "=" ";" __san "${__san}")
  list(GET __san 0 __san_option)
  list(GET __san 1 __san_flag)
  if(PX_ENABLE_${__san_option})
    list(APPEND __san_flags ${__san_flag})
  endif()
endforeach()
list(JOIN __san_flags "," __san_flags)

if(PX_ENABLE_TSAN AND (PX_ENABLE_ASAN OR PX_ENABLE_MSAN OR PX_ENABLE_LSAN))
  log_fatal("PX_ENABLE_TSAN: TSan can't be combined with ASan, MSan or LSan")
endif()
if(PX_ENABLE_MSAN AND (PX_ENABLE_ASAN OR PX_ENABLE_LSAN))
  log_fatal("PX_ENABLE_MSAN: MSan can't be combined with ASan or LSan")
endif()

set(__san_clang_cl OFF)
if(MSVC AND CMAKE_CXX_COMPILER_ID STREQUAL "Clang")
  set(__san_clang_cl ON)
endif()

if(MSVC)
  if(PX_ENABLE_TSAN OR PX_ENABLE_MSAN OR PX_ENABLE_LSAN)
    log_fatal("MSVC and clang-cl only have ASan and UBSan (UBSan: clang-cl only)")
  endif()
  if(PX_ENABLE_UBSAN AND NOT __san_clang_cl)
    log_fatal("PX_ENABLE_UBSAN: MSVC has no UBSan (clang-cl has)")
  endif()
  # /fsanitize=address rejects CMake's Debug /RTC*. Deps keep theirs (no ASan).
  if(PX_ENABLE_ASAN)
    foreach(lang C CXX)
      string(REGEX REPLACE "/RTC[1csu]*" "" CMAKE_${lang}_FLAGS_DEBUG "${CMAKE_${lang}_FLAGS_DEBUG}")
    endforeach()
  endif()

  # cl needs no link flag (link.exe infers the runtime). CMake links clang-cl
  # with the linker, not the driver, so the runtime the driver would add is
  # missing: take it from the driver's dry run (names vary by LLVM version).
  set(__san_link_options "")
  if(__san_clang_cl AND __san_flags)
    execute_process(COMMAND "${CMAKE_CXX_COMPILER}" /clang:-print-runtime-dir
      OUTPUT_VARIABLE __san_rt_dir OUTPUT_STRIP_TRAILING_WHITESPACE)
    file(TO_CMAKE_PATH "${__san_rt_dir}" __san_rt_dir)
    if(NOT IS_DIRECTORY "${__san_rt_dir}")
      log_fatal("clang-cl ${CMAKE_CXX_COMPILER_VERSION} has no sanitizer runtime (${__san_rt_dir}): "
        "install LLVM's compiler-rt (PX_ENABLE_*SAN)")
    endif()
    set(__san_crt /MD)
    if(CMAKE_MSVC_RUNTIME_LIBRARY AND NOT CMAKE_MSVC_RUNTIME_LIBRARY MATCHES "DLL")
      set(__san_crt /MT)
    endif()
    set(__san_obj "${CMAKE_BINARY_DIR}/CMakeFiles/__px_san.obj")
    file(TOUCH "${__san_obj}")
    execute_process(COMMAND "${CMAKE_CXX_COMPILER}" ${__san_crt} -fsanitize=${__san_flags} "-###" "${__san_obj}"
      OUTPUT_VARIABLE __san_out ERROR_VARIABLE __san_out)
    string(REGEX MATCHALL "\"[^\"]*(clang_rt|__asan)[^\"]*\"" __san_args "${__san_out}")
    string(REPLACE "\"" "" __san_args "${__san_args}")
    string(REPLACE "\\\\" "/" __san_args "${__san_args}")
    # UBSan's objects name their runtime libs without a path.
    set(__san_link_options "/LIBPATH:${__san_rt_dir}" ${__san_args})
  endif()

  # Running ASan exes needs the runtime DLL, which isn't on PATH for clang-cl
  # (and for cl only in developer prompts): copied next to each exe.
  if(PX_ENABLE_ASAN)
    string(REPLACE "x64" "x86_64" __san_arch "${CMAKE_CXX_COMPILER_ARCHITECTURE_ID}")
    string(REPLACE "ARM64" "aarch64" __san_arch "${__san_arch}")
    string(REPLACE "X86" "i386" __san_arch "${__san_arch}")
    cmake_path(GET CMAKE_CXX_COMPILER PARENT_PATH __san_cxx_dir)
    find_file(__san_asan_dll NAMES clang_rt.asan_dynamic-${__san_arch}.dll clang_rt.asan_dynamic.dll
      PATHS "${__san_cxx_dir}" "${__san_rt_dir}" NO_DEFAULT_PATH NO_CACHE)
  endif()
elseif(PX_ENABLE_MSAN AND NOT CMAKE_CXX_COMPILER_ID STREQUAL "Clang")
  log_fatal("PX_ENABLE_MSAN: MSan needs Clang (CC=clang CXX=clang++), not ${CMAKE_CXX_COMPILER_ID}")
elseif(__san_flags)
  # Not every toolchain ships the runtimes (MinGW GCC, for one; TSan, MSan
  # and LSan only exist on some platforms).
  include(CheckCXXSourceCompiles)
  string(MAKE_C_IDENTIFIER "__px_sanitize_${__san_flags}" __san_ok)
  set(CMAKE_REQUIRED_FLAGS "-fsanitize=${__san_flags}")
  set(CMAKE_REQUIRED_QUIET ON)
  check_cxx_source_compiles("int main() { return 0; }" ${__san_ok})
  unset(CMAKE_REQUIRED_FLAGS)
  unset(CMAKE_REQUIRED_QUIET)
  if(NOT ${__san_ok})
    log_fatal("${CMAKE_CXX_COMPILER_ID} ${CMAKE_CXX_COMPILER_VERSION} can't build with -fsanitize=${__san_flags}: "
      "this toolchain has no runtime for it on this platform (PX_ENABLE_*SAN)")
  endif()
endif()

function(setup_sanitizers project_name)

  if(NOT __san_flags)
    return()
  endif()

  # Libs: their objects need the runtime, so whatever links them (a plain
  # parent's exe, an installed lib's consumer) links it too.
  get_target_property(type ${project_name} TYPE)
  set(scope PUBLIC)
  if(type STREQUAL "EXECUTABLE")
    set(scope PRIVATE)
  endif()

  if(MSVC)
    if(PX_ENABLE_ASAN)
      # ASan doesn't support incremental linking (CMake's Debug default).
      target_link_options(${project_name} PRIVATE /INCREMENTAL:NO)
      if(type STREQUAL "EXECUTABLE" AND __san_asan_dll)
        add_custom_command(TARGET ${project_name} POST_BUILD
          COMMAND ${CMAKE_COMMAND} -E copy_if_different "${__san_asan_dll}" "$<TARGET_FILE_DIR:${project_name}>")
      endif()
    endif()
    if(NOT __san_clang_cl)
      # link.exe ignores the flag (LNK4044); the compiler pulls in the runtime.
      target_compile_options(${project_name} PRIVATE /fsanitize=${__san_flags})
      return()
    endif()
    # clang-cl rejects /fsanitize=undefined.
    target_compile_options(${project_name} PRIVATE -fsanitize=${__san_flags})
    target_link_options(${project_name} ${scope} ${__san_link_options})
  else()
    target_compile_options(${project_name} PRIVATE -fsanitize=${__san_flags} -fno-omit-frame-pointer)
    target_link_options(${project_name} ${scope} -fsanitize=${__san_flags})
  endif()

  # Otherwise UBSan only prints, and tests pass.
  if(PX_ENABLE_UBSAN)
    target_compile_options(${project_name} PRIVATE -fno-sanitize-recover=undefined)
  endif()

endfunction()
