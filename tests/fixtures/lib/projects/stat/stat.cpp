#include "stat.hpp"

#include <fmt/format.h>

namespace st {
std::string make(int x) {
    return fmt::format("stat {}", x);
}
} // namespace st
