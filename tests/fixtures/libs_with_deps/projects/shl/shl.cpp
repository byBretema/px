#include "shl.hpp"

#include <fmt/format.h>

namespace shl {
std::string make(int x) {
    return fmt::format("shl {}", x);
}
} // namespace shl
