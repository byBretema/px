#include <fmt/format.h>
#include <hdr.hpp>
#include <shl.hpp>

int main() {
    return hdr::valid(fmt::format("{}", shl::make(1))) ? 0 : 1;
}
