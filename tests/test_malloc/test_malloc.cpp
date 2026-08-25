#include <atomic>
#include <chrono>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <random>
#include <thread>
#include <vector>

#if defined(__linux__) || defined(__APPLE__)
#include <dlfcn.h>
#elif defined(_WIN32)
#include <windows.h>
#endif

#ifdef USE_MIMALLOC
#include <mimalloc.h>
#endif

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

using Clock = std::chrono::high_resolution_clock;

struct BenchResult {
    const char *name;
    double      ms;
    std::size_t ops;
    std::size_t bytes;
};

static void print_result(BenchResult const &r) {
    double throughput_mb = 0.0;
    if (r.bytes > 0) {
        throughput_mb = static_cast<double>(r.bytes) / (1024.0 * 1024.0) / (r.ms / 1000.0);
    }
    std::printf("  %-36s %8.2f ms  %10zu ops  %8.2f MB/s\n",
                r.name, r.ms, r.ops, throughput_mb);
}

// ---------------------------------------------------------------------------
// 1. Small alloc/dealloc throughput (random sizes 16-256 B)
// ---------------------------------------------------------------------------
static BenchResult bench_small_alloc(std::size_t count) {
    std::mt19937 rng(42);
    std::uniform_int_distribution<int> dist(16, 256);

    auto t0 = Clock::now();
    for (std::size_t i = 0; i < count; ++i) {
        std::size_t sz = static_cast<std::size_t>(dist(rng));
        void *p = std::malloc(sz);
        std::free(p);
    }
    auto t1 = Clock::now();

    double ms = std::chrono::duration<double, std::milli>(t1 - t0).count();
    return {"small alloc+free (16-256B)", ms, count, 0};
}

// ---------------------------------------------------------------------------
// 2. Medium alloc/dealloc throughput (1 KB - 64 KB)
// ---------------------------------------------------------------------------
static BenchResult bench_medium_alloc(std::size_t count) {
    std::mt19937 rng(42);
    std::uniform_int_distribution<int> dist(1024, 65536);

    auto t0 = Clock::now();
    for (std::size_t i = 0; i < count; ++i) {
        std::size_t sz = static_cast<std::size_t>(dist(rng));
        void *p = std::malloc(sz);
        std::free(p);
    }
    auto t1 = Clock::now();

    double ms = std::chrono::duration<double, std::milli>(t1 - t0).count();
    return {"medium alloc+free (1-64KB)", ms, count, 0};
}

// ---------------------------------------------------------------------------
// 3. Large alloc/dealloc throughput (256 KB - 4 MB)
// ---------------------------------------------------------------------------
static BenchResult bench_large_alloc(std::size_t count) {
    std::mt19937 rng(42);
    std::uniform_int_distribution<int> dist(256 * 1024, 4 * 1024 * 1024);

    std::size_t total_bytes = 0;
    auto t0 = Clock::now();
    for (std::size_t i = 0; i < count; ++i) {
        std::size_t sz = static_cast<std::size_t>(dist(rng));
        void *p = std::malloc(sz);
        std::free(p);
        total_bytes += sz;
    }
    auto t1 = Clock::now();

    double ms = std::chrono::duration<double, std::milli>(t1 - t0).count();
    return {"large alloc+free (256KB-4MB)", ms, count, total_bytes};
}

// ---------------------------------------------------------------------------
// 4. Batch alloc then batch free (fragmentation stress)
// ---------------------------------------------------------------------------
static BenchResult bench_batch_fragmentation(std::size_t count) {
    std::mt19937 rng(42);
    std::uniform_int_distribution<int> dist(32, 4096);

    std::vector<void *> ptrs(count);
    std::vector<std::size_t> sizes(count);

    // Allocate all
    for (std::size_t i = 0; i < count; ++i) {
        sizes[i] = static_cast<std::size_t>(dist(rng));
        ptrs[i] = std::malloc(sizes[i]);
    }

    // Free in reverse order (worst-case for fragmentation)
    auto t0 = Clock::now();
    for (std::size_t i = count; i-- > 0;) {
        std::free(ptrs[i]);
    }
    auto t1 = Clock::now();

    double ms = std::chrono::duration<double, std::milli>(t1 - t0).count();
    return {"batch free reverse (32-4KB)", ms, count, 0};
}

// ---------------------------------------------------------------------------
// 5. Random interleaved alloc/free (realistic workload)
// ---------------------------------------------------------------------------
static BenchResult bench_interleaved(std::size_t ops) {
    std::mt19937 rng(42);
    std::uniform_int_distribution<int> size_dist(32, 2048);
    std::uniform_real_distribution<double> coin(0.0, 1.0);

    std::vector<void *> pool;
    pool.reserve(1024);

    auto t0 = Clock::now();
    for (std::size_t i = 0; i < ops; ++i) {
        if (pool.empty() || coin(rng) < 0.6) {
            std::size_t sz = static_cast<std::size_t>(size_dist(rng));
            pool.push_back(std::malloc(sz));
        } else {
            std::size_t idx = std::uniform_int_distribution<std::size_t>(0, pool.size() - 1)(rng);
            std::free(pool[idx]);
            pool[idx] = pool.back();
            pool.pop_back();
        }
    }
    // Cleanup remaining
    for (void *p : pool) {
        std::free(p);
    }
    auto t1 = Clock::now();

    double ms = std::chrono::duration<double, std::milli>(t1 - t0).count();
    return {"interleaved alloc/free mix", ms, ops, 0};
}

// ---------------------------------------------------------------------------
// 6. Multi-threaded small alloc (N threads, each doing count ops)
// ---------------------------------------------------------------------------
static void thread_worker(std::size_t count, std::atomic<std::size_t> &counter) {
    std::mt19937 rng(std::hash<std::thread::id>{}(std::this_thread::get_id()));
    std::uniform_int_distribution<int> dist(16, 512);

    for (std::size_t i = 0; i < count; ++i) {
        std::size_t sz = static_cast<std::size_t>(dist(rng));
        void *p = std::malloc(sz);
        std::free(p);
    }
    counter.fetch_add(count, std::memory_order_relaxed);
}

static BenchResult bench_threaded(std::size_t threads_per_op, std::size_t ops_per_thread) {
    std::atomic<std::size_t> counter{0};

    auto t0 = Clock::now();
    std::vector<std::thread> pool;
    pool.reserve(threads_per_op);
    for (std::size_t t = 0; t < threads_per_op; ++t) {
        pool.emplace_back(thread_worker, ops_per_thread, std::ref(counter));
    }
    for (auto &th : pool) {
        th.join();
    }
    auto t1 = Clock::now();

    double ms = std::chrono::duration<double, std::milli>(t1 - t0).count();
    return {"multi-threaded alloc+free", ms, counter.load(), 0};
}

// ---------------------------------------------------------------------------
// 7. Realloc growth pattern (e.g. building a string/vector)
// ---------------------------------------------------------------------------
static BenchResult bench_realloc_growth(std::size_t rounds) {
    auto t0 = Clock::now();
    for (std::size_t r = 0; r < rounds; ++r) {
        std::size_t cap = 64;
        void *p = std::malloc(cap);
        for (int i = 0; i < 16; ++i) {
            cap *= 2;
            p = std::realloc(p, cap);
        }
        std::free(p);
    }
    auto t1 = Clock::now();

    double ms = std::chrono::duration<double, std::milli>(t1 - t0).count();
    return {"realloc growth (64B->2MB)", ms, rounds * 16, 0};
}

// ===========================================================================
int main() {
    std::puts("================================================================");
    std::puts("         MIMALLOC STRESS TEST — Allocation Benchmark");
    std::puts("================================================================");
    std::puts("");

    // Detect if mimalloc is active by probing for mi_version symbol
    {
        bool found = false;
#if defined(__linux__)
        found = (dlsym(RTLD_DEFAULT, "mi_version") != nullptr);
#elif defined(_WIN32)
        found = (GetProcAddress(GetModuleHandleA("mimalloc.dll"), "mi_version") != nullptr);
#elif defined(__APPLE__)
        found = (dlsym(RTLD_DEFAULT, "mi_version") != nullptr);
#endif
        if (found) {
            std::puts("  Allocator: mimalloc");
#ifdef USE_MIMALLOC
            mi_option_set(mi_option_page_full_retain, 1);
            mi_option_set(mi_option_purge_decommits, 0);
#endif
        } else {
            std::puts("  Allocator: system default");
        }
    }
    std::puts("");

    constexpr std::size_t M = 1000000;

    std::puts("--- Allocation Throughput ---");
    print_result(bench_small_alloc(M * 10));
    print_result(bench_medium_alloc(M));
    print_result(bench_large_alloc(M / 10));
    std::puts("");

    std::puts("--- Fragmentation Stress ---");
    print_result(bench_batch_fragmentation(M));
    print_result(bench_interleaved(M * 2));
    std::puts("");

    std::puts("--- Concurrency ---");
    print_result(bench_threaded(4, M * 5));
    print_result(bench_threaded(8, M * 5));
    std::puts("");

    std::puts("--- Realloc ---");
    print_result(bench_realloc_growth(M / 100));
    std::puts("");

    std::puts("================================================================");
    std::puts("  All benchmarks completed.");
    std::puts("================================================================");

    return 0;
}
