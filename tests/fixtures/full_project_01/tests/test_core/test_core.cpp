#include <cstdlib>

#include "logger.hpp"

// Not assert(): NDEBUG compiles it out, so Release tests would check nothing.
#define CHECK(expr)                                                       \
    do {                                                                  \
        if (!(expr)) {                                                    \
            y::err("{}:{}: CHECK failed: {}", __FILE__, __LINE__, #expr); \
            std::exit(1);                                                 \
        }                                                                 \
    } while (false)

int main() {
    y::println("=================== RUNNING TinyFmt TESTS ===================\n");

    // ------------------------------------------------------------------------
    // 1. Primitive & Character Formatting Tests
    // ------------------------------------------------------------------------
    y::println("[1] Primitive & Character Formatting:\n");

    // Test char vs integer
    char              ch       = 'Z';
    const std::string res_char = y::format("Char: {}", ch);
    CHECK(res_char == "Char: Z");
    y::println("  \u2713 Single char: {}", res_char);

    // Test booleans
    const std::string res_bool = y::format("Bools: {} / {}", true, false);
    CHECK(res_bool == "Bools: true / false");
    y::println("  \u2713 Booleans: {}", res_bool);

    // Test numbers (int, float, negative)
    const std::string res_nums = y::format("Int: {}, Float: {}, Neg: {}", 42, 3.1415, -100);
    y::println("  \u2713 Numbers: {}", res_nums);

    // ------------------------------------------------------------------------
    // 2. String Types Tests
    // ------------------------------------------------------------------------
    y::println("\n[2] String Types Handling:");

    // const char*
    const char* c_str = "hello c-string";
    CHECK(y::format("{}", c_str) == "hello c-string");

    // nullptr const char*
    const char* null_c_str = nullptr;
    CHECK(y::format("{}", null_c_str) == "(null)");

    // Mutable char array (char*) - must NOT print as hexadecimal address
    char              mut_str[] = "mutable string";
    const std::string res_mut   = y::format("{}", mut_str);
    CHECK(res_mut == "mutable string");
    y::println("  \u2713 Mutable char*: {}", res_mut);

    // std::string
    const std::string cpp_str = "std::string object";
    CHECK(y::format("{}", cpp_str) == "std::string object");

    // std::string_view
    std::string_view sv = "std::string_view object";
    CHECK(y::format("{}", sv) == "std::string_view object");
    y::println("  \u2713 std::string and std::string_view passing passed.");

    // ------------------------------------------------------------------------
    // 3. Pointer Formatting Tests
    // ------------------------------------------------------------------------
    y::println("\n[3] Pointer Formatting:");

    int   dummy    = 10;
    int*  ptr      = &dummy;
    void* null_ptr = nullptr;

    const std::string res_ptr = y::format("Ptr: {}, Null: {}", static_cast<void*>(ptr), null_ptr);
    CHECK(res_ptr.find("0x") != std::string::npos);
    CHECK(res_ptr.find("nullptr") != std::string::npos);
    y::println("  \u2713 Pointer outputs: {}", res_ptr);

    // ------------------------------------------------------------------------
    // 4. Heap Spill / Buffer Migration Test (Exceeding 16-byte stack limit)
    // ------------------------------------------------------------------------
    y::println("\n[4] Heap Overflow / Migration Test:");

    y::detail::fmt::DynamicBuffer<16> tiny_buf; // Small 16-byte capacity
    const std::string large_input = "This payload is significantly larger than 16 bytes!";
    y::detail::fmt::to_buffer(tiny_buf, "{}", large_input);

    CHECK(tiny_buf.view() == large_input);
    y::println("  \u2713 Tiny buffer spill to heap migration passed.");

    // ------------------------------------------------------------------------
    // 5. Logging Macros & Early Exit Function Tests
    // ------------------------------------------------------------------------
    y::println("\n[5] Logging Output Tests:");

    y::println("Simple println string");
    y::info("Info message");
    y::warn("Warn message");
    y::err("Err message");

    y::info("Formatted Info: User {} (ID: {}) logged in", "Alice", 1'001);
    y::err("Formatted Err: Failed to connect to {}:{}", "127.0.0.1", 8'080);

    // Test with_* early exit helpers
    y::println("\n[6] Testing Early Exit Helpers:");
    auto val = with_warn("Validating config...", 42);
    CHECK(val == 42);

    y::println("\n================ ALL TESTS PASSED SUCCESSFULLY ================");
    return 0;
}
