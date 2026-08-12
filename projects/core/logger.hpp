#pragma once

#include <charconv>
#include <cstdint>
#include <cstring>
#include <iostream>
#include <string>
#include <string_view>
#include <type_traits>
#include <utility>

#include "polyfills/charconv_fp.hpp"

namespace y::detail {

namespace fmt {

// --- Buffer logic ---

struct Buffer {
  char *stack_ptr_;
  size_t capacity_;
  size_t size_ = 0;
  std::string heap_buf_;

  Buffer(char *ptr, size_t cap) noexcept : stack_ptr_(ptr), capacity_(cap) {}

  void append(std::string_view sv) {
    if (heap_buf_.empty()) {
      if (size_ + sv.size() <= capacity_) {
        std::memcpy(stack_ptr_ + size_, sv.data(), sv.size());
        size_ += sv.size();
        return;
      }
      heap_buf_.reserve(size_ + sv.size() + 2048);
      heap_buf_.assign(stack_ptr_, size_);
    }
    heap_buf_.append(sv);
  }

  [[nodiscard]] std::string_view view() const noexcept {
    return heap_buf_.empty() ? std::string_view(stack_ptr_, size_)
                             : std::string_view(heap_buf_);
  }
};

template <size_t Cap = 1024> struct DynamicBuffer : public Buffer {
  char storage_[Cap];
  DynamicBuffer() noexcept : Buffer(storage_, Cap) {}
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
  if constexpr (std::is_floating_point_v<T> && Y_POLYFILL_CHARCONV_FP) {
    append_fp_fallback(buf, val);
  } else {
    char temp[64];
    auto [ptr, ec] = std::to_chars(temp, temp + sizeof(temp), val);
    if (ec == std::errc{}) {
      buf.append(std::string_view(
          temp, static_cast<std::string_view::size_type>(ptr - temp)));
    }
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
  std::cout.write(out.data(), static_cast<std::streamsize>(out.size()));
}

} // namespace y::detail

namespace y {

// --- Format ---

template <typename... Targs>
inline std::string format(std::string_view str, const Targs &...args) {
  y::detail::fmt::DynamicBuffer<1024> buffer;
  y::detail::fmt::to_buffer(buffer, str, args...);
  // Explicitly construct std::string to avoid dangling string_view UB
  std::string_view v = buffer.view();
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
