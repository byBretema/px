include("${CMAKE_CURRENT_LIST_DIR}/ProjectSetup.cmake")

# ---------------------------------------------------------------------------
# Printing — fmtlib
# ---------------------------------------------------------------------------
import_dependency(fmt::fmt
  GITHUB fmtlib/fmt
  TAG        11.1.4
  OPTIONS    FMT_INSTALL=OFF FMT_TEST=OFF FMT_DOC=OFF
)

# ---------------------------------------------------------------------------
# Networking — Asio (standalone)
# ---------------------------------------------------------------------------
import_dependency(asio::asio
  GITHUB chriskohlhoff/asio
  TAG        asio-1-38-2
  OPTIONS    ASIO_STANDALONE=ON ASIO_NO_DEPRECATED=ON
)

# ---------------------------------------------------------------------------
# HTTP Server — cpp-httplib
# ---------------------------------------------------------------------------
import_dependency(httplib::httplib
  GITHUB yhirose/cpp-httplib
  TAG        v0.18.2
)

# ---------------------------------------------------------------------------
# HTTP Requests — cpr
# ---------------------------------------------------------------------------
import_dependency(cpr::cpr
  GITHUB libcpr/cpr
  TAG        1.11.1
  OPTIONS    CPR_BUILD_TESTS=OFF CPR_BUILD_EXAMPLES=OFF CPR_USE_SYSTEM_CURL=ON
)

# ---------------------------------------------------------------------------
# JSON — Glaze
# ---------------------------------------------------------------------------
import_dependency(glaze::glaze
  GITHUB stephenberry/glaze
  TAG        v7.9.1
  OPTIONS    glaze_BUILD_TEST=OFF glaze_INSTALL=OFF
)

# ---------------------------------------------------------------------------
# Unicode — utfcpp
# ---------------------------------------------------------------------------
import_dependency(utfcpp::utfcpp
  GITHUB nemtrif/utfcpp
  TAG        v4.0.6
)

# ---------------------------------------------------------------------------
# CLI Args — argparse
# ---------------------------------------------------------------------------
import_dependency(argparse::argparse
  GITHUB p-ranav/argparse
  TAG        v3.2
)

# ---------------------------------------------------------------------------
# Maths — GLM
# ---------------------------------------------------------------------------
import_dependency(glm::glm
  GITHUB g-truc/glm
  TAG        1.0.1
  OPTIONS    GLM_TEST_ENABLE=OFF GLM_INSTALL_ENABLE=OFF
)

# ---------------------------------------------------------------------------
# Regex — CTRE
# ---------------------------------------------------------------------------
import_dependency(ctre::ctre
  GITHUB hanickadot/compile-time-regular-expressions
  TAG        v3.10.0
)

# ---------------------------------------------------------------------------
# tl::expected — C++20 polyfill for std::expected (C++23)
# ---------------------------------------------------------------------------
import_dependency(tl::expected
  GITHUB TartanLlama/expected
  TAG        v1.1.0
)

# ---------------------------------------------------------------------------
# Function2 — fu2::function
# ---------------------------------------------------------------------------
import_dependency(fu2::function
  GITHUB Naios/function2
  TAG        4.2.2
)

# ---------------------------------------------------------------------------
# Better Enums
# ---------------------------------------------------------------------------
import_dependency(enum::enum
  GITHUB aantron/better-enums
  TAG        0.11.3
)

# ---------------------------------------------------------------------------
# Ranges — range-v3
# ---------------------------------------------------------------------------
import_dependency(range-v3::range-v3
  GITHUB ericniebler/range-v3
  TAG        0.12.0
  OPTIONS    RANGES_BUILD_CALENDAR_EXAMPLE=OFF RANGES_BUILD_DOCS=OFF RANGE_V3_TESTS=OFF RANGE_V3_EXAMPLES=OFF RANGE_V3_PERF=OFF RANGE_V3_HEADER_CHECKS=OFF
)

# ---------------------------------------------------------------------------
# Hash map/set — unordered_dense (replaces abseil flat_hash_map/flat_hash_set)
# ---------------------------------------------------------------------------
import_dependency(unordered_dense::unordered_dense
  GITHUB martinus/unordered_dense
  TAG        v4.8.1
)

# ---------------------------------------------------------------------------
# EASTL — east::string / east::vector
# ---------------------------------------------------------------------------
import_dependency(EASTL::EASTL
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
# import_dependency(gpu::gpu
#   GITHUB grimfang4/sdl-gpu
#   TAG        master
#   OPTIONS    SDL_GPU_DISABLE_PNG=ON SDL_GPU_DISABLE_NPOT=ON
# )
# ---------------------------------------------------------------------------
