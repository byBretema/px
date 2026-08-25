# Stress test for mimalloc effectiveness

make_test(test_malloc)
target_link_mimalloc(test_malloc)
