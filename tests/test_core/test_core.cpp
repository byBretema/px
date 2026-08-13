#include <cassert>

#include "logger.hpp"

int main() {
    std::cout << "=================== RUNNING TinyFmt TESTS ===================\n\n";

    // ------------------------------------------------------------------------
    // 1. Primitive & Character Formatting Tests
    // ------------------------------------------------------------------------
    std::cout << "[1] Primitive & Character Formatting:\n\n";

    // Test char vs integer
    char ch = 'Z';
    std::string const res_char = y::format("Char: {}", ch);
    assert(res_char == "Char: Z");
    std::cout << "  \u2713 Single char: " << res_char << '\n';

    // Test booleans
    std::string const res_bool = y::format("Bools: {} / {}", true, false);
    assert(res_bool == "Bools: true / false");
    std::cout << "  \u2713 Booleans: " << res_bool << '\n';

    // Test numbers (int, float, negative)
    std::string const res_nums = y::format("Int: {}, Float: {}, Neg: {}", 42, 3.1415, -100);
    std::cout << "  \u2713 Numbers: " << res_nums << '\n';

    // ------------------------------------------------------------------------
    // 2. String Types Tests
    // ------------------------------------------------------------------------
    std::cout << "\n[2] String Types Handling:\n";

    // const char*
    const char* c_str = "hello c-string";
    assert(y::format("{}", c_str) == "hello c-string");

    // nullptr const char*
    const char* null_c_str = nullptr;
    assert(y::format("{}", null_c_str) == "(null)");

    // Mutable char array (char*) - must NOT print as hexadecimal address
    char mut_str[] = "mutable string";
    std::string const res_mut = y::format("{}", mut_str);
    assert(res_mut == "mutable string");
    std::cout << "  \u2713 Mutable char*: " << res_mut << '\n';

    // std::string
    std::string const cpp_str = "std::string object";
    assert(y::format("{}", cpp_str) == "std::string object");

    // std::string_view
    std::string_view sv = "std::string_view object";
    assert(y::format("{}", sv) == "std::string_view object");
    std::cout << "  \u2713 std::string and std::string_view passing passed.\n";

    // ------------------------------------------------------------------------
    // 3. Pointer Formatting Tests
    // ------------------------------------------------------------------------
    std::cout << "\n[3] Pointer Formatting:\n";

    int dummy = 10;
    int* ptr = &dummy;
    void* null_ptr = nullptr;

    std::string const res_ptr = y::format("Ptr: {}, Null: {}", static_cast<void*>(ptr), null_ptr);
    assert(res_ptr.find("0x") != std::string::npos);
    assert(res_ptr.find("nullptr") != std::string::npos);
    std::cout << "  \u2713 Pointer outputs: " << res_ptr << '\n';

    // ------------------------------------------------------------------------
    // 4. Heap Spill / Buffer Migration Test (Exceeding 16-byte stack limit)
    // ------------------------------------------------------------------------
    std::cout << "\n[4] Heap Overflow / Migration Test:\n";

    y::detail::fmt::DynamicBuffer<16> tiny_buf; // Small 16-byte capacity
    std::string const large_input = "This payload is significantly larger than 16 bytes!";
    y::detail::fmt::to_buffer(tiny_buf, "{}", large_input);

    assert(tiny_buf.view() == large_input);
    std::cout << "  \u2713 Tiny buffer spill to heap migration passed.\n";

    // ------------------------------------------------------------------------
    // 5. Logging Macros & Early Exit Function Tests
    // ------------------------------------------------------------------------
    std::cout << "\n[5] Logging Output Tests:\n";

    y::println("Simple println string");
    y::info("Info message");
    y::warn("Warn message");
    y::err("Err message");

    y::info("Formatted Info: User {} (ID: {}) logged in", "Alice", 1001);
    y::err("Formatted Err: Failed to connect to {}:{}", "127.0.0.1", 8080);

    // Test with_* early exit helpers
    std::cout << "\n[6] Testing Early Exit Helpers:\n";
    auto val = with_warn("Validating config...", 42);
    assert(val == 42);

    std::cout << "\n================ ALL TESTS PASSED SUCCESSFULLY ================\n";
    return 0;
}
