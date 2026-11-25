#include <hdr.hpp>
#include <shl.hpp>
#include <stat.hpp>

#ifndef PX_PATCHED_UTFCPP
#error the patched utfcpp headers were not used
#endif

int main() {
    return hdr::valid(shl::make(1) + st::make(2)) ? 0 : 1;
}
