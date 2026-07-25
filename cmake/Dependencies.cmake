include("${CMAKE_CURRENT_LIST_DIR}/Nest.cmake")

# ---------------------------------------------------------------------------
# Printing — fmtlib
# ---------------------------------------------------------------------------
Nest_Import(fmt::fmt
  GITHUB fmtlib/fmt
  TAG        11.1.4
  OPTIONS    FMT_INSTALL=OFF FMT_TEST=OFF FMT_DOC=OFF
)

# ---------------------------------------------------------------------------
# Networking — Asio (standalone)
# ---------------------------------------------------------------------------
Nest_Import(asio::asio
  GITHUB chriskohlhoff/asio
  TAG        asio-1-38-2
  OPTIONS    ASIO_STANDALONE=ON ASIO_NO_DEPRECATED=ON
)

# ---------------------------------------------------------------------------
# HTTP Server — cpp-httplib
# ---------------------------------------------------------------------------
Nest_Import(httplib::httplib
  GITHUB yhirose/cpp-httplib
  TAG        v0.18.2
)

# ---------------------------------------------------------------------------
# HTTP Requests — cpr
# ---------------------------------------------------------------------------
Nest_Import(cpr::cpr
  GITHUB libcpr/cpr
  TAG        1.11.1
  OPTIONS    CPR_BUILD_TESTS=OFF CPR_BUILD_EXAMPLES=OFF CPR_USE_SYSTEM_CURL=OFF CPR_FIND_PACKAGE_ARGS=ON
)

# ---------------------------------------------------------------------------
# JSON — Glaze
# ---------------------------------------------------------------------------
Nest_Import(glaze::glaze
  GITHUB stephenberry/glaze
  TAG        v7.9.1
  OPTIONS    glaze_BUILD_TEST=OFF glaze_INSTALL=OFF
)

# ---------------------------------------------------------------------------
# Unicode — utfcpp
# ---------------------------------------------------------------------------
Nest_Import(utfcpp::utfcpp
  GITHUB nemtrif/utfcpp
  TAG        v4.0.6
)

# ---------------------------------------------------------------------------
# CLI Args — argparse
# ---------------------------------------------------------------------------
Nest_Import(argparse::argparse
  GITHUB p-ranav/argparse
  TAG        v3.2
)

# ---------------------------------------------------------------------------
# Maths — GLM
# ---------------------------------------------------------------------------
Nest_Import(glm::glm
  GITHUB g-truc/glm
  TAG        1.0.1
  OPTIONS    GLM_TEST_ENABLE=OFF GLM_INSTALL_ENABLE=OFF
)

# ---------------------------------------------------------------------------
# Regex — CTRE
# ---------------------------------------------------------------------------
Nest_Import(ctre::ctre
  GITHUB hanickadot/compile-time-regular-expressions
  TAG        v3.10.0
)

# ---------------------------------------------------------------------------
# tl::optional
# ---------------------------------------------------------------------------
Nest_Import(tl::optional
  GITHUB TartanLlama/optional
  TAG        v1.1.0
)

# ---------------------------------------------------------------------------
# tl::expected
# ---------------------------------------------------------------------------
Nest_Import(tl::expected
  GITHUB TartanLlama/expected
  TAG        v1.1.0
)

# ---------------------------------------------------------------------------
# tc::span
# ---------------------------------------------------------------------------
Nest_Import(tc::span
  GITHUB tcbrindle/span
  TAG        master
  PATCH      "${CMAKE_CURRENT_LIST_DIR}/patches/tc-span-disable-testing.cmake"
)

# ---------------------------------------------------------------------------
# Function2 — fu2::function
# ---------------------------------------------------------------------------
Nest_Import(fu2::function
  GITHUB Naios/function2
  TAG        4.2.2
)

# ---------------------------------------------------------------------------
# Better Enums
# ---------------------------------------------------------------------------
Nest_Import(enum::enum
  GITHUB aantron/better-enums
  TAG        0.11.3
)

# ---------------------------------------------------------------------------
# Ranges — range-v3
# ---------------------------------------------------------------------------
Nest_Import(range-v3::range-v3
  GITHUB ericniebler/range-v3
  TAG        0.12.0
  OPTIONS    RANGES_BUILD_CALENDAR_EXAMPLE=OFF RANGES_BUILD_DOCS=OFF RANGE_V3_TESTS=OFF RANGE_V3_EXAMPLES=OFF RANGE_V3_PERF=OFF RANGE_V3_HEADER_CHECKS=OFF
)

# ---------------------------------------------------------------------------
# Abseil — flat_hash_map / flat_hash_set
# ---------------------------------------------------------------------------
Nest_Import(absl::flat_hash_map
  GITHUB abseil/abseil-cpp
  TAG        20250127.0
  OPTIONS    ABSL_PROPAGATE_CXX_STD=ON ABSL_BUILD_TESTING=OFF ABSL_USE_EXTERNAL_GOOGLETEST=OFF
)
Nest_Import(absl::flat_hash_set
  GITHUB abseil/abseil-cpp
  TAG        20250127.0
  OPTIONS    ABSL_PROPAGATE_CXX_STD=ON ABSL_BUILD_TESTING=OFF ABSL_USE_EXTERNAL_GOOGLETEST=OFF
)

# ---------------------------------------------------------------------------
# EASTL — east::string / east::vector
# ---------------------------------------------------------------------------
Nest_Import(EASTL::EASTL
  GITHUB electronicarts/EASTL
  TAG        3.21.23
  OPTIONS    EASTL_BUILD_TESTS=OFF EASTL_BUILD_BENCHMARK=OFF
)

# ---------------------------------------------------------------------------
# SDL-gpu — Graphics (requires SDL2)
# NOTE: SDL-gpu depends on SDL2 + OpenGL and may need system packages.
#       Uncomment and adapt the following block once SDL2 is available.
#
# find_package(SDL2 REQUIRED)
# Nest_Import(gpu::gpu
#   GITHUB grimfang4/sdl-gpu
#   TAG        master
#   OPTIONS    SDL_GPU_DISABLE_PNG=ON SDL_GPU_DISABLE_NPOT=ON
# )
# ---------------------------------------------------------------------------
