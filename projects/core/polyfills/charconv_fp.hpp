// ============================================================================
// charconv_fp.hpp - Floating-point std::to_chars polyfill
//
// std::to_chars overloads for floating-point types are not shipped by every
// standard library (they exist only from: libstdc++ GCC>=11, libc++ LLVM>=14,
// and MSVC STL VS2019 16.4 / _MSC_VER>=1924). When missing, the helper below
// falls back to std::snprintf so callers can keep a single code path.
//
// ============================================================================

#pragma once

#include <type_traits>

// ----------------------------------------------------------------------------
// DETECTION: Y_POLYFILL_CHARCONV_FP
// Defaults to 0 on modern toolchains, to 1 when FP overloads not supported.
// Define Y_FORCE_POLYFILL_CHARCONV_FP sets it to 1. (e.g. for testing)
// ----------------------------------------------------------------------------

#if defined(Y_FORCE_POLYFILL_CHARCONV_FP)
  #define Y_POLYFILL_CHARCONV_FP 1
#elif defined(_MSC_VER) && _MSC_VER >= 1924
  // MSVC VS2019 16.4+ ships FP to_chars
#elif defined(__clang__) && defined(_LIBCPP_VERSION) && _LIBCPP_VERSION >= 14000
  // libc++ 14+ ships FP to_chars
#elif defined(__GNUC__) && defined(__GLIBCXX__) && __GNUC__ >= 11
  // GCC 11+ with libstdc++ ships FP to_chars; note: libstdc++ omits
  // __cpp_lib_to_chars here, so detection must be version-based, not macro-based
#else
  #define Y_POLYFILL_CHARCONV_FP 1
#endif

#ifndef Y_POLYFILL_CHARCONV_FP
  #define Y_POLYFILL_CHARCONV_FP 0
#endif

// ----------------------------------------------------------------------------
// IMPLEMENTATION:
// Only defined when the polyfill is active. It appends a floating-point value
// to a generic buffer using std::snprintf with the default %g precision.
// ----------------------------------------------------------------------------

#if Y_POLYFILL_CHARCONV_FP

#pragma message("-- Using polyfill to support charconv on fp numbers")

#include <cstdio> // <- snprintf

namespace y::detail {

template <typename T>
inline std::size_t append_fp_fallback(char *buf, std::size_t bufSize, T val) {
  int n;
  if constexpr (std::is_same_v<T, long double>) {
    n = std::snprintf(buf, bufSize, "%Lg", val);
  } else {
    n = std::snprintf(buf, bufSize, "%g", static_cast<double>(val));
  }
  return (n > 0 && static_cast<std::size_t>(n) < bufSize)
             ? static_cast<std::size_t>(n)
             : 0;
}

} // namespace y::detail

#endif
