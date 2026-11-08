# C++ standard of own targets: set(PX_CXX_STANDARD <n>) before post_project().
# A compile feature, so installed libs carry it to consumers.
if(NOT DEFINED PX_CXX_STANDARD)
  set(PX_CXX_STANDARD 23)
endif()
set(__cxx_std cxx_std_${PX_CXX_STANDARD})

if(NOT __cxx_std IN_LIST CMAKE_CXX_COMPILE_FEATURES)
  log_fatal("${CMAKE_CXX_COMPILER_ID} ${CMAKE_CXX_COMPILER_VERSION} has no C++${PX_CXX_STANDARD} support (PX_CXX_STANDARD)")
endif()
log_status("C++ standard     -> ${PX_CXX_STANDARD}")
