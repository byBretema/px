// Fails to compile unless cmake/patches/*.cmake were applied to the deps.
#include <argparse/argparse.hpp>
#include <utf8.h>

static_assert(PX_PATCHED_ARGPARSE == 1, "argparse patch not applied");
static_assert(PX_PATCHED_UTFCPP == 1, "utfcpp patch not applied");

int main() {
    return 0;
}
