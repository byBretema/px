// TSan: threads write counter unsynchronized. Several, as TSan can miss a
// single racing pair (a few % of runs).
#include <array>
#include <thread>

namespace {
int counter = 0;
}

int main() {
  std::array<std::thread, 8> threads;
  for (auto& thread : threads) {
    thread = std::thread([] { ++counter; });
  }
  ++counter;
  for (auto& thread : threads) {
    thread.join();
  }
  return counter > 0 ? 0 : 1;
}
