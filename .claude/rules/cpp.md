---
description: C++ conventions for px sources.
paths:
  - "**/*.{cpp,cc,cxx,c,hpp,hh,hxx,h}"
---

- C++23, extensions off; `std::expected`, no polyfills. No exceptions.
- `#pragma once`. Angle brackets for stdlib, quotes for project headers.
- `snake_case` functions/vars/params, `PascalCase` types, `m_` private members.
- Namespaces: `y` public API, `y::detail` internals.
- `std::string_view` for read-only params, `std::string` for owned data; `[[nodiscard]]` / `[[maybe_unused]]` as needed.
- `static_cast` only (old-style casts warn).
- Formatting: `.clang-format` is the authority; `just format` applies it, `just format_check` is the CI check. The clang-format version is pinned by the project in `.clang-format` (`# clang-format-version: <v>`, read by `cmake/utils/format.cmake` and CI); other versions warn, older majors fail.
- Must build clean under `debug-strict` (warnings as errors); flags in `cmake/configs/warnings.cmake`.
- Tests: always-on `CHECK()` macro, not `assert()` (compiled out by `NDEBUG` in Release).
