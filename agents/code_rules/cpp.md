# C++ Rules

## Standard

- C++23 (`CMAKE_CXX_STANDARD 23`, extensions off, required); glaze requires it
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
- `assert()` for test invariants

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
