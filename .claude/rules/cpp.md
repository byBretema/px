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
- 4-space indent, attached braces.
- Must build clean under `debug-strict` (warnings as errors); flags in `cmake/configs/warnings.cmake`.
- Tests: always-on `CHECK()` macro, not `assert()` (compiled out by `NDEBUG` in Release).
