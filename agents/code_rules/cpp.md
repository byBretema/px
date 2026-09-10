# C++ Rules

## Standard

- C++20 (`CMAKE_CXX_STANDARD 20`, extensions off, required)

## Header guards

- `#pragma once`

## Naming

- `snake_case` functions, variables, parameters
- `PascalCase` structs/classes
- `m_` prefix for private members
- Double-underscore prefix for internal CMake functions (not C++)

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

- 4-space indent
- Opening brace on same line
- K&R / Allman hybrid

## Compiler warnings

- `-Wall -Wextra -Wpedantic` plus:
  - `-Wconversion -Wsign-conversion -Wshadow`
  - `-Wnon-virtual-dtor -Wold-style-cast -Wcast-align -Wunused`
  - `-Woverloaded-virtual -Wnull-dereference -Wformat=2 -Wundef`
  - `-Wdouble-promotion -Wimplicit-fallthrough -Wno-float-equal`
- GCC adds: `-Wmisleading-indentation -Wduplicated-cond -Wduplicated-branches -Wlogical-op -Wuseless-cast`
- Clang adds: `-Wno-c++98-compat -Wno-c++98-compat-pedantic -Wno-language-extension-token`
