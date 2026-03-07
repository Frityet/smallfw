#include <errno.h>
#include <limits.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#include "smallfw/Object.h"
#include "runtime/internal.h"

#if defined(__clang__)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wpre-c23-compat"
#pragma clang diagnostic ignored "-Wunsafe-buffer-usage"
#pragma clang diagnostic ignored "-Wdeclaration-after-statement"
#endif

#define SFW_NEW(T) [[T allocWithAllocator:sf_default_allocator()] init]
#define SFW_RELEASE(obj) do { if ((obj) != NULL) objc_release((obj)); } while (0)

@interface BenchMono : Object
- (int)calc:(int)x;
@end
@implementation BenchMono
- (int)calc:(int)x {
    return x + 1;
}
@end

@interface BenchPolyA : Object
- (int)calc:(int)x;
@end
@implementation BenchPolyA
- (int)calc:(int)x {
    return x + 1;
}
@end

@interface BenchPolyB : Object
- (int)calc:(int)x;
@end
@implementation BenchPolyB
- (int)calc:(int)x {
    return x + 2;
}
@end

@interface BenchARC : Object
@end
@implementation BenchARC
@end

static uint64_t now_ns(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ((uint64_t)ts.tv_sec * UINT64_C(1000000000)) + (uint64_t)ts.tv_nsec;
}

static int bench_dispatch_monomorphic_hot(int iters, volatile uint64_t *sink) {
    BenchMono *obj = SFW_NEW(BenchMono);
    int local = 0;

    if (obj == NULL) {
        return 0;
    }

    for (int i = 0; i < iters; ++i) {
        local += [obj calc:i];
    }

    *sink ^= (uint64_t)local;
    objc_release(obj);
    return 1;
}

static int bench_dispatch_polymorphic_hot(int iters, volatile uint64_t *sink) {
    BenchPolyA *a = SFW_NEW(BenchPolyA);
    BenchPolyB *b = SFW_NEW(BenchPolyB);
    int local = 0;

    if (a == NULL || b == NULL) {
        SFW_RELEASE(a);
        SFW_RELEASE(b);
        return 0;
    }

    for (int i = 0; i < iters; ++i) {
        if ((((unsigned int)i) & 1U) == 0U) {
            local += [a calc:i];
        } else {
            local += [b calc:i];
        }
    }

    *sink ^= (uint64_t)local;
    objc_release(a);
    objc_release(b);
    return 1;
}

static int bench_dispatch_nil_receiver_hot(int iters, volatile uint64_t *sink) {
    BenchMono *obj = NULL;
    int local = 0;

    for (int i = 0; i < iters; ++i) {
        local += [obj calc:i];
    }

    *sink ^= (uint64_t)local;
    return 1;
}

static int bench_arc_retain_release_heap(int iters, volatile uint64_t *sink) {
    BenchARC *obj = SFW_NEW(BenchARC);

    for (int i = 0; i < iters; ++i) {
        id r = objc_retain(obj);
        objc_release(r);
    }

    *sink ^= (uint64_t)(uintptr_t)obj;
    objc_release(obj);
    return 1;
}

static int bench_arc_retain_release_round_robin(int iters, volatile uint64_t *sink) {
    enum { pool_size = 256 };
    BenchARC *objs[pool_size];

    memset(objs, 0, sizeof(objs));
    for (int i = 0; i < pool_size; ++i) {
        objs[i] = SFW_NEW(BenchARC);
        if (objs[i] == NULL) {
            for (int j = 0; j < i; ++j) {
                SFW_RELEASE(objs[j]);
            }
            return 0;
        }
    }

    for (int i = 0; i < iters; ++i) {
        BenchARC *obj = objs[((unsigned int)i) & (pool_size - 1U)];
        id r = objc_retain(obj);
        objc_release(r);
    }

    *sink ^= (uint64_t)(uintptr_t)objs[((unsigned int)iters) & (pool_size - 1U)];
    for (int i = 0; i < pool_size; ++i) {
        SFW_RELEASE(objs[i]);
    }
    return 1;
}

static int bench_arc_store_strong_cycle(int iters, volatile uint64_t *sink) {
    BenchARC *a = SFW_NEW(BenchARC);
    BenchARC *b = SFW_NEW(BenchARC);
    id slot = NULL;

    if (a == NULL || b == NULL) {
        SFW_RELEASE(a);
        SFW_RELEASE(b);
        return 0;
    }

    for (int i = 0; i < iters; ++i) {
        objc_storeStrong(&slot, ((((unsigned int)i) & 1U) == 0U) ? a : b);
    }

    *sink ^= (uint64_t)(uintptr_t)slot;
    objc_storeStrong(&slot, NULL);
    objc_release(a);
    objc_release(b);
    return 1;
}

static int bench_alloc_init_release_plain(int iters, volatile uint64_t *sink) {
    uint64_t local = 0;

    for (int i = 0; i < iters; ++i) {
        BenchARC *obj = SFW_NEW(BenchARC);
        if (obj == NULL) {
            return 0;
        }
        local ^= (uint64_t)(uintptr_t)obj;
        objc_release(obj);
    }

    *sink ^= local;
    return 1;
}

static int bench_parent_group_cycle(int iters, volatile uint64_t *sink) {
    uint64_t local = 0;

    for (int i = 0; i < iters; ++i) {
        BenchARC *root = SFW_NEW(BenchARC);
        BenchARC *child = [[BenchARC allocWithParent:root] init];
        if (root == NULL || child == NULL) {
            SFW_RELEASE(child);
            SFW_RELEASE(root);
            return 0;
        }
        local ^= (uint64_t)(uintptr_t)child;
        objc_release(child);
        objc_release(root);
    }

    *sink ^= local;
    return 1;
}

typedef int (*BenchFn)(int iters, volatile uint64_t *sink);
typedef struct BenchCase {
    const char *name;
    BenchFn fn;
    int default_iters;
    int reserved;
} BenchCase;

static const BenchCase g_benches[] = {
    {.name = "dispatch_monomorphic_hot", .fn = bench_dispatch_monomorphic_hot, .default_iters = 50000000},
    {.name = "dispatch_polymorphic_hot", .fn = bench_dispatch_polymorphic_hot, .default_iters = 50000000},
    {.name = "dispatch_nil_receiver_hot", .fn = bench_dispatch_nil_receiver_hot, .default_iters = 50000000},
    {.name = "arc_retain_release_heap", .fn = bench_arc_retain_release_heap, .default_iters = 50000000},
    {.name = "arc_retain_release_round_robin", .fn = bench_arc_retain_release_round_robin, .default_iters = 20000000},
    {.name = "arc_store_strong_cycle", .fn = bench_arc_store_strong_cycle, .default_iters = 20000000},
    {.name = "alloc_init_release_plain", .fn = bench_alloc_init_release_plain, .default_iters = 2000000},
    {.name = "parent_group_cycle", .fn = bench_parent_group_cycle, .default_iters = 1000000},
};

static int run_bench(const BenchCase *bench, int iters, volatile uint64_t *sink) {
    uint64_t t0 = now_ns();
    int ok = bench->fn(iters, sink);
    uint64_t t1 = now_ns();

    if (!ok) {
        return 0;
    }

    uint64_t total_ns = t1 - t0;
    double ns_per = (iters > 0) ? ((double)total_ns / (double)iters) : 0.0;
    printf("%s,%d,%llu,%.3f\n", bench->name, iters, (unsigned long long)total_ns, ns_per);
    return 1;
}

int main(int argc, char **argv) {
    const char *case_name = NULL;
    int iters = 0;
    int list_only = 0;

    for (int i = 1; i < argc; ++i) {
        if (strcmp(argv[i], "--list") == 0) {
            list_only = 1;
            continue;
        }
        if (strcmp(argv[i], "--case") == 0 && (i + 1) < argc) {
            case_name = argv[++i];
            continue;
        }
        if (strcmp(argv[i], "--iters") == 0 && (i + 1) < argc) {
            char *end = NULL;
            const char *raw = argv[++i];
            errno = 0;
            long parsed = strtol(raw, &end, 10);
            if (errno != 0 || end == raw || *end != '\0' || parsed < 1L || parsed > (long)INT_MAX) {
                fprintf(stderr, "invalid --iters value: %s\n", raw);
                return 2;
            } else {
                iters = (int)parsed;
            }
            continue;
        }
    }

    if (list_only) {
        for (size_t i = 0; i < sizeof(g_benches) / sizeof(g_benches[0]); ++i) {
            printf("%s,%d\n", g_benches[i].name, g_benches[i].default_iters);
        }
        return 0;
    }

    if (case_name == NULL) {
        fprintf(stderr, "missing --case <name|all> [--iters N]\n");
        return 2;
    }

    volatile uint64_t sink = 0;
    if (strcmp(case_name, "all") == 0) {
        for (size_t i = 0; i < sizeof(g_benches) / sizeof(g_benches[0]); ++i) {
            int bench_iters = (iters > 0) ? iters : g_benches[i].default_iters;
            if (!run_bench(&g_benches[i], bench_iters, &sink)) {
                return 1;
            }
        }
        return sink == UINT64_C(0xdeadbeefdeadbeef);
    }

    for (size_t i = 0; i < sizeof(g_benches) / sizeof(g_benches[0]); ++i) {
        if (strcmp(g_benches[i].name, case_name) == 0) {
            int bench_iters = (iters > 0) ? iters : g_benches[i].default_iters;
            int ok = run_bench(&g_benches[i], bench_iters, &sink);
            if (!ok) {
                return 1;
            }
            return sink == UINT64_C(0xdeadbeefdeadbeef);
        }
    }

    fprintf(stderr, "unknown case: %s\n", case_name);
    return 3;
}

#if defined(__clang__)
#pragma clang diagnostic pop
#endif
