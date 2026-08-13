#pragma once

#include <charconv>
#include <cstdio>
#include <cstdint>
#include <cstring>
#include <string>
#include <string_view>
#include <type_traits>
#include <utility>

#include "polyfills/charconv_fp.hpp"

namespace y::detail {

namespace fmt {

// --- Buffer logic ---

struct Buffer {
  Buffer(char *ptr, size_t cap) noexcept : m_stack_ptr(ptr), m_capacity(cap) {}

  void append(std::string_view sv) {
    if (m_heap_buf.empty()) {
      if (m_size + sv.size() <= m_capacity) {
        std::memcpy(m_stack_ptr + m_size, sv.data(), sv.size());
        m_size += sv.size();
        return;
      }
      m_heap_buf.reserve(m_size + sv.size() + 2048);
      m_heap_buf.assign(m_stack_ptr, m_size);
    }
    m_heap_buf.append(sv);
  }

  [[nodiscard]] std::string_view view() const noexcept {
    return m_heap_buf.empty() ? std::string_view(m_stack_ptr, m_size)
                              : std::string_view(m_heap_buf);
  }

private:
  char *m_stack_ptr;
  size_t m_capacity;
  size_t m_size = 0;
  std::string m_heap_buf;
};

template <size_t Cap = 1024> struct DynamicBuffer : public Buffer {
  DynamicBuffer() noexcept : Buffer(m_storage, Cap) {}

private:
  char m_storage[Cap];
};

// --- Placeholder logic ---

// Splits fmt at the next placeholder marker "{}". Returns the literal text
// preceding it (a zero-copy view into fmt) and advances fmt past the marker.
inline std::string_view extract_until_placeholder(std::string_view &fmt) noexcept {
  size_t open = fmt.find('{');
  if (open == std::string_view::npos) {
    std::string_view literal = fmt;
    fmt = {};
    return literal;
  }
  size_t close = fmt.find('}', open + 1);
  if (close == std::string_view::npos) {
    std::string_view literal = fmt;
    fmt = {};
    return literal;
  }
  std::string_view literal = fmt.substr(0, open);
  fmt.remove_prefix(close + 1);
  return literal;
}

// --- Type Appenders ---

// Catch string views, std::string, and char arrays
template <typename T>
  requires std::is_convertible_v<T, std::string_view> && (!std::is_pointer_v<T>)
inline void append_value(Buffer &buf, const T &str) {
  buf.append(std::string_view(str));
}

inline void append_value(Buffer &buf, char c) {
  buf.append(std::string_view(&c, 1));
}

inline void append_value(Buffer &buf, const char *str) {
  buf.append(str ? std::string_view(str) : "(null)");
}

inline void append_value(Buffer &buf, bool b) {
  buf.append(b ? "true" : "false");
}

template <typename T>
  requires std::is_arithmetic_v<T> && (!std::is_same_v<T, bool>) &&
           (!std::is_same_v<std::remove_cv_t<T>, char>)
inline void append_value(Buffer &buf, T val) {
  char temp[64];
  std::size_t len = 0;
  if constexpr (std::is_floating_point_v<T> && Y_POLYFILL_CHARCONV_FP) {
    len = append_fp_fallback(temp, sizeof(temp), val);
  } else {
    auto [ptr, ec] = std::to_chars(temp, temp + sizeof(temp), val);
    if (ec == std::errc{}) {
      len = static_cast<std::size_t>(ptr - temp);
    }
  }
  if (len > 0) {
    buf.append(std::string_view(temp, len));
  }
}

template <typename T>
  requires std::is_pointer_v<T> &&
           (!std::is_same_v<std::remove_cv_t<std::remove_pointer_t<T>>, char>)
inline void append_value(Buffer &buf, T ptr) {
  if (!ptr) {
    buf.append("nullptr");
    return;
  }
  buf.append("0x");
  char temp[32];
  auto uintptr = reinterpret_cast<uintptr_t>(ptr);
  auto [p, ec] = std::to_chars(temp, temp + sizeof(temp), uintptr, 16);
  if (ec == std::errc{}) {
    buf.append(std::string_view(
        temp, static_cast<std::string_view::size_type>(p - temp)));
  }
}

template <typename... Args>
inline std::string_view to_buffer(Buffer &buf, std::string_view fmt,
                                  const Args &...args) {
  [[maybe_unused]] auto process_arg = [&](const auto &arg) {
    buf.append(extract_until_placeholder(fmt));
    append_value(buf, arg);
  };

  (process_arg(args), ...);
  buf.append(fmt);
  return buf.view();
}

template <typename... Args>
inline void format_to_buf(Buffer &buf, std::string_view fmt,
                          const Args &...args) {
  to_buffer(buf, fmt, args...);
}

} // namespace fmt

template <typename... Targs>
inline void print(std::string_view prefix, std::string_view m,
                  const Targs &...args) {
  y::detail::fmt::DynamicBuffer<1024> buf;
  if (!prefix.empty()) {
    buf.append(prefix);
  }
  y::detail::fmt::to_buffer(buf, m, args...);
  buf.append("\n");
  std::string_view out = buf.view();
  std::fwrite(out.data(), 1, out.size(), stdout);
}

} // namespace y::detail

namespace y {

// --- Format ---

template <typename... Targs>
inline std::string format(std::string_view str, const Targs &...args) {
  y::detail::fmt::DynamicBuffer<1024> buffer;
  y::detail::fmt::to_buffer(buffer, str, args...);
  std::string_view v = buffer.view(); // Avoids dangling string_view UB
  return std::string(v.data(), v.size());
}

// --- Log helpers ---

template <typename... Targs>
inline void println(std::string_view m, const Targs &...args) {
  y::detail::print("", m, args...);
}

template <typename... Targs>
inline void info(std::string_view m, const Targs &...args) {
  y::detail::print("-- ", m, args...);
}

template <typename... Targs>
inline void err(std::string_view m, const Targs &...args) {
  y::detail::print("E · ", m, args...);
}

template <typename... Targs>
inline void warn(std::string_view m, const Targs &...args) {
  y::detail::print("W · ", m, args...);
}

} // namespace y

// --- Early Exit Helpers ---

template <typename T = bool>
[[nodiscard]] decltype(auto) with_info(std::string_view msg, T &&v = false) {
  y::info(msg);
  return std::forward<T>(v);
}

template <typename T = bool>
[[nodiscard]] decltype(auto) with_warn(std::string_view msg, T &&v = false) {
  y::warn(msg);
  return std::forward<T>(v);
}

template <typename T = bool>
[[nodiscard]] decltype(auto) with_err(std::string_view msg, T &&v = false) {
  y::err(msg);
  return std::forward<T>(v);
}
