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

#include <string_view>
#include <type_traits>

// ----------------------------------------------------------------------------
// DETECTION
//
// Sets Y_POLYFILL_CHARCONV_FP to 1 when the FP overloads may be absent.
// Define Y_FORCE_POLYFILL_CHARCONV_FP to force the fallback path (e.g. for
// testing), and Y_POLYFILL_CHARCONV_FP defaults to 0 on modern toolchains.
// ----------------------------------------------------------------------------

#if defined(Y_FORCE_POLYFILL_CHARCONV_FP)
  #define Y_POLYFILL_CHARCONV_FP 1
#elif defined(_MSC_VER)
  #if _MSC_VER < 1924
  #define Y_POLYFILL_CHARCONV_FP 1
  #endif
#elif defined(__clang__)
  #if defined(_LIBCPP_VERSION)
    #if _LIBCPP_VERSION < 14000
    #define Y_POLYFILL_CHARCONV_FP 1
    #endif
  #elif defined(__GLIBCXX__) && defined(__GNUC__) && __GNUC__ < 11
    #define Y_POLYFILL_CHARCONV_FP 1
  #else
    #define Y_POLYFILL_CHARCONV_FP 1
  #endif
#elif defined(__GNUC__)
  #if defined(__GLIBCXX__)
    #if __GNUC__ < 11
      #define Y_POLYFILL_CHARCONV_FP 1
      #endif
    #else
      #define Y_POLYFILL_CHARCONV_FP 1
    #endif
  #else
    #define Y_POLYFILL_CHARCONV_FP 1
#endif

#ifndef Y_POLYFILL_CHARCONV_FP
  #define Y_POLYFILL_CHARCONV_FP 0
#endif

// ----------------------------------------------------------------------------
// IMPLEMENTATION
//
// Only defined when the fallback is active, so its dependencies (<cstdio>)
// are pulled in exactly on the toolchains that need them. It appends a
// floating-point value to a generic buffer using std::snprintf with the
// default %g precision (6 significant digits), matching how most values are
// displayed while keeping the output short.
// ----------------------------------------------------------------------------

#if Y_POLYFILL_CHARCONV_FP

#include <cstdio> // snprintf fallback for FP to_chars

namespace y::detail {

template <typename Buf, typename T>
inline void append_fp_fallback(Buf &buf, T val) {
  char temp[64];
  int n;
  if constexpr (std::is_same_v<T, long double>) {
    n = std::snprintf(temp, sizeof(temp), "%Lg", val);
  } else {
    n = std::snprintf(temp, sizeof(temp), "%g", static_cast<double>(val));
  }
  if (n > 0) {
    buf.append(std::string_view(
        temp, static_cast<std::string_view::size_type>(n)));
  }
}

} // namespace y::detail

#endif
