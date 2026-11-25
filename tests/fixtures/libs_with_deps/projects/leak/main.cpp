// LSan: the only pointer to the allocation is overwritten. A direct
// ::operator new call, not a new-expression: optimizers may drop the latter.
#include <new>

namespace {
void* volatile sink = nullptr;
}

int main() {
  sink = ::operator new(64);
  sink = nullptr;
  return 0;
}
