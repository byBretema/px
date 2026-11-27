// Hardening: each mode has a bug the checks must abort on. The size comes
// from the command line so the compiler can't see the overflow and warn.
#include <cstdlib>
#include <cstring>
#include <string_view>
#include <vector>

int main(int argc, char** argv) {
  if (argc < 3) {
    return 1;
  }
  const std::string_view mode = argv[1];
  const std::size_t n = std::strtoul(argv[2], nullptr, 10);
  if (mode == "fortify") {
    char dst[4];
    std::memcpy(dst, argv[0], n);
    return dst[0];
  }
  if (mode == "stl") {
    std::vector<int> v(1);
    return v[n];
  }
  return 1;
}
