# C++ Rules

## Standard

- C++23 minimum (`cxx_std_23` compile feature on own targets, extensions off); glaze requires it
- Use `std::expected` (no polyfill)

## Header guards

- `#pragma once`

## Naming

- `snake_case` functions, variables, parameters
- `PascalCase` structs/classes
- `m_` prefix for private members

## Types

- `std::string_view` preferred for read-only parameters
- `std::string` for owned data
- `[[nodiscard]]`, `[[maybe_unused]]` as needed

## Casting

- `static_cast` only (old-style-cast warning enabled)

## Error handling

- No exceptions
- Tests: an always-on `CHECK()` macro for invariants, not `assert()` (compiled out by `NDEBUG` in Release)

## Namespaces

- `y` for public API
- `y::detail` for internal implementation

## Includes

- Angle brackets for stdlib
- Quotes for project headers

## Formatting

- 2-space indent
- Opening brace on same line (attached)

## Compiler warnings

- Source of truth: `cmake/configs/warnings.cmake` (GCC, Clang, MSVC sets)
- Code must build clean under the `debug-strict` preset (warnings as errors)
