# Trivial patch exercising the PATCH path; checked by tests/test_patch.
file(APPEND "${nemtrif_utfcpp_SOURCE_DIR}/source/utf8.h" "\n#define PX_PATCHED_UTFCPP 1\n")
