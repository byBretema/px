#pragma once
#include <argparse/argparse.hpp>
#include <utf8.h>

#include <string>

namespace hdr {
inline bool valid(const std::string& s) {
    return utf8::is_valid(s);
}
} // namespace hdr
