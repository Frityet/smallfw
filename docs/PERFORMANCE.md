# Runtime Performance Matrix

This document is generated from measured `xmake run-runtime-bench` runs on the current host. The matrix uses `analysis-symbols=n` by default so release rows reflect a shipping-style binary unless a row explicitly says otherwise.

Generated at: `2026-03-12T14:05:28Z`
Regenerate with: `xmake run-runtime-performance-matrix --samples=2 --warmups=1 --outdir=build/runtime-analysis/performance-matrix --doc=docs/PERFORMANCE.md`

## Environment

- Host: `linux`
- Architecture: `x86_64`
- `uname -srvm`: `Linux 6.17.7-ba25.fc43.x86_64 #1 SMP PREEMPT_DYNAMIC Mon Jan 19 05:47:43 UTC 2026 x86_64`
- `clang --version`: `Debian clang version 21.1.8 (++20251221033036+2078da43e25a-1~exp1~20251221153213.50)`
- `xmake --version`: `xmake v3.0.7+20260312, A cross-platform build utility based on Lua`
- Samples per variant: `2`
- Warmups per variant: `1`
- Benchmark artifact root: `/workspaces/smallfw/build/runtime-analysis/performance-matrix`

## Variant Definitions

| Variant | Category | Mode | PGO | BOLT | Changed Options | Status | Failure | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `debug-default` | Modes | `debug` | `off` | `off` | - | ok | - | Debug build with runtime defaults. |
| `release-default` | Modes | `release` | `off` | `off` | - | ok | - | Release build with runtime defaults. This is the matrix baseline. |
| `release-native-tuning` | Whole-program | `release` | `off` | `off` | `runtime-native-tuning=y` | ok | - | Enables -march=native and -mtune=native. |
| `release-thinlto` | Whole-program | `release` | `off` | `off` | `runtime-thinlto=y` | ok | - | Enables ThinLTO. |
| `release-full-lto` | Whole-program | `release` | `off` | `off` | `runtime-full-lto=y` | ok | - | Enables full LTO. |
| `release-pgo-gen` | Instrumentation | `release` | `gen` | `off` | - | ok | - | Instrumentation-only PGO generation build. |
| `release-pgo-use` | Whole-program | `release` | `use` | `off` | - | ok | - | Profile-guided optimization on the default release stack. |
| `release-pgo-use-bolt` | Whole-program | `release` | `use` | `on` | `analysis-symbols=y` | ok | - | Default release stack with PGO and BOLT. |
| `release-max-opt` | Whole-program | `release` | `off` | `off` | `runtime-native-tuning=y`, `runtime-thinlto=y`, `dispatch-l0-dual=y`, `dispatch-cache-2way=y`, `dispatch-cache-negative=y`, `runtime-compact-headers=y`, `runtime-fast-objects=y`, `runtime-inline-value-storage=y`, `runtime-inline-group-state=y` | ok | - | Recommended tuned release stack without profile feedback. |
| `release-max-opt-pgo` | Whole-program | `release` | `use` | `off` | `runtime-native-tuning=y`, `runtime-thinlto=y`, `dispatch-l0-dual=y`, `dispatch-cache-2way=y`, `dispatch-cache-negative=y`, `runtime-compact-headers=y`, `runtime-fast-objects=y`, `runtime-inline-value-storage=y`, `runtime-inline-group-state=y` | ok | - | Recommended tuned release stack with PGO. |
| `release-max-opt-pgo-bolt` | Whole-program | `release` | `use` | `on` | `analysis-symbols=y`, `runtime-native-tuning=y`, `runtime-thinlto=y`, `dispatch-l0-dual=y`, `dispatch-cache-2way=y`, `dispatch-cache-negative=y`, `runtime-compact-headers=y`, `runtime-fast-objects=y`, `runtime-inline-value-storage=y`, `runtime-inline-group-state=y` | ok | - | Recommended tuned release stack with PGO and BOLT. |
| `release-dispatch-c` | Dispatch / behavior | `release` | `off` | `off` | `dispatch-backend=c` | ok | - | Uses the C message send path instead of the assembly fast path. |
| `release-dispatch-stats` | Dispatch / behavior | `release` | `off` | `off` | `dispatch-stats=y` | ok | - | Enables dispatch cache statistics counters. |
| `release-forwarding` | Dispatch / behavior | `release` | `off` | `off` | `runtime-forwarding=y` | ok | - | Enables forwarding and runtime selector resolution. |
| `release-validation` | Dispatch / behavior | `release` | `off` | `off` | `runtime-validation=y` | ok | - | Adds defensive object validation checks. |
| `release-tagged-pointers` | Dispatch / behavior | `release` | `off` | `off` | `runtime-tagged-pointers=y` | ok | - | Enables tagged pointer support. |
| `release-threadsafe` | Dispatch / behavior | `release` | `off` | `off` | `runtime-threadsafe=y` | failed | `src/runtime/dispatch_x86_64.asm:198:43: error: unknown token in expression` | Adds synchronized runtime bookkeeping. |
| `release-exceptions-off` | Dispatch / behavior | `release` | `off` | `off` | `runtime-exceptions=n` | ok | - | Disables Objective-C exceptions support. |
| `release-reflection-off` | Dispatch / behavior | `release` | `off` | `off` | `runtime-reflection=n` | ok | - | Disables reflection support. |
| `release-dispatch-l0-dual` | Dispatch / behavior | `release` | `off` | `off` | `dispatch-l0-dual=y` | ok | - | Enables the dual-entry L0 dispatch cache. |
| `release-dispatch-cache-2way` | Dispatch / behavior | `release` | `off` | `off` | `dispatch-cache-2way=y` | ok | - | Enables a 2-way dispatch cache. |
| `release-dispatch-cache-negative` | Dispatch / behavior | `release` | `off` | `off` | `dispatch-cache-2way=y`, `dispatch-cache-negative=y` | ok | - | Enables negative cache entries and its 2-way cache prerequisite. |
| `release-compact-headers` | Layout / ABI | `release` | `off` | `off` | `runtime-compact-headers=y` | ok | - | Uses the compact runtime object header layout. |
| `release-fast-objects` | Layout / ABI | `release` | `off` | `off` | `runtime-compact-headers=y`, `runtime-fast-objects=y` | ok | - | Enables FastObject paths and the compact-header prerequisite. |
| `release-inline-value-storage` | Layout / ABI | `release` | `off` | `off` | `runtime-compact-headers=y`, `runtime-inline-value-storage=y` | ok | - | Enables compact inline ValueObject prefixes and the compact-header prerequisite. |
| `release-inline-group-state` | Layout / ABI | `release` | `off` | `off` | `runtime-compact-headers=y`, `runtime-inline-group-state=y` | ok | - | Stores parent/group bookkeeping inline and enables the compact-header prerequisite. |
| `release-analysis-symbols` | Instrumentation | `release` | `off` | `off` | `analysis-symbols=y` | ok | - | Keeps debug symbols, disables strip, and emits relocations. |
| `release-sanitize` | Instrumentation | `release` | `off` | `off` | `runtime-sanitize=y` | ok | - | AddressSanitizer and UndefinedBehaviorSanitizer enabled. |

## Leaderboard

| Rank | Variant | Category | Geo Mean vs `release-default` | Best Case | Worst Case | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | `release-max-opt-pgo` | Whole-program | 1.72x | `arc_store_strong_cycle` (3.60x) | `dispatch_nil_receiver_hot` (1.00x) | Recommended tuned release stack with PGO. |
| 2 | `release-max-opt-pgo-bolt` | Whole-program | 1.70x | `arc_store_strong_cycle` (3.53x) | `dispatch_nil_receiver_hot` (0.96x) | Recommended tuned release stack with PGO and BOLT. |
| 3 | `release-full-lto` | Whole-program | 1.69x | `arc_store_strong_cycle` (3.43x) | `dispatch_nil_receiver_hot` (0.97x) | Enables full LTO. |
| 4 | `release-thinlto` | Whole-program | 1.55x | `arc_store_strong_cycle` (3.53x) | `dispatch_nil_receiver_hot` (0.97x) | Enables ThinLTO. |
| 5 | `release-pgo-use` | Whole-program | 1.21x | `arc_retain_release_heap` (1.66x) | `dispatch_nil_receiver_hot` (1.00x) | Profile-guided optimization on the default release stack. |
| 6 | `release-max-opt` | Whole-program | 1.19x | `arc_store_strong_cycle` (2.42x) | `parent_group_cycle` (0.92x) | Recommended tuned release stack without profile feedback. |
| 7 | `release-pgo-use-bolt` | Whole-program | 1.09x | `arc_retain_release_heap` (1.68x) | `dispatch_polymorphic_hot` (0.49x) | Default release stack with PGO and BOLT. |
| 8 | `release-default` | Modes | 1.00x | `dispatch_monomorphic_hot` (1.00x) | `dispatch_monomorphic_hot` (1.00x) | Release build with runtime defaults. This is the matrix baseline. |
| 9 | `release-analysis-symbols` | Instrumentation | 0.99x | `dispatch_monomorphic_hot` (1.00x) | `dispatch_polymorphic_hot` (0.98x) | Keeps debug symbols, disables strip, and emits relocations. |
| 10 | `release-exceptions-off` | Dispatch / behavior | 0.99x | `alloc_init_release_plain` (1.04x) | `arc_store_strong_cycle` (0.96x) | Disables Objective-C exceptions support. |
| 11 | `release-reflection-off` | Dispatch / behavior | 0.98x | `dispatch_monomorphic_hot` (1.01x) | `arc_store_strong_cycle` (0.91x) | Disables reflection support. |
| 12 | `release-validation` | Dispatch / behavior | 0.98x | `arc_retain_release_round_robin` (1.08x) | `alloc_init_release_plain` (0.87x) | Adds defensive object validation checks. |
| 13 | `release-native-tuning` | Whole-program | 0.96x | `dispatch_monomorphic_hot` (1.00x) | `parent_group_cycle` (0.88x) | Enables -march=native and -mtune=native. |
| 14 | `release-dispatch-l0-dual` | Dispatch / behavior | 0.96x | `alloc_init_release_plain` (1.00x) | `dispatch_monomorphic_hot` (0.88x) | Enables the dual-entry L0 dispatch cache. |
| 15 | `release-compact-headers` | Layout / ABI | 0.96x | `dispatch_monomorphic_hot` (1.02x) | `parent_group_cycle` (0.75x) | Uses the compact runtime object header layout. |
| 16 | `release-fast-objects` | Layout / ABI | 0.94x | `dispatch_monomorphic_hot` (1.00x) | `parent_group_cycle` (0.75x) | Enables FastObject paths and the compact-header prerequisite. |
| 17 | `release-forwarding` | Dispatch / behavior | 0.93x | `arc_retain_release_round_robin` (1.02x) | `arc_store_strong_cycle` (0.79x) | Enables forwarding and runtime selector resolution. |
| 18 | `release-inline-group-state` | Layout / ABI | 0.91x | `dispatch_nil_receiver_hot` (0.99x) | `arc_retain_release_round_robin` (0.64x) | Stores parent/group bookkeeping inline and enables the compact-header prerequisite. |
| 19 | `release-dispatch-stats` | Dispatch / behavior | 0.91x | `arc_retain_release_round_robin` (1.01x) | `dispatch_polymorphic_hot` (0.55x) | Enables dispatch cache statistics counters. |
| 20 | `release-inline-value-storage` | Layout / ABI | 0.90x | `dispatch_monomorphic_hot` (1.01x) | `parent_group_cycle` (0.57x) | Enables compact inline ValueObject prefixes and the compact-header prerequisite. |
| 21 | `release-dispatch-cache-2way` | Dispatch / behavior | 0.89x | `dispatch_nil_receiver_hot` (1.00x) | `dispatch_polymorphic_hot` (0.52x) | Enables a 2-way dispatch cache. |
| 22 | `release-tagged-pointers` | Dispatch / behavior | 0.87x | `dispatch_nil_receiver_hot` (0.99x) | `arc_retain_release_round_robin` (0.59x) | Enables tagged pointer support. |
| 23 | `release-dispatch-cache-negative` | Dispatch / behavior | 0.87x | `arc_store_strong_cycle` (0.99x) | `dispatch_polymorphic_hot` (0.63x) | Enables negative cache entries and its 2-way cache prerequisite. |
| 24 | `release-pgo-gen` | Instrumentation | 0.56x | `arc_store_strong_cycle` (0.85x) | `dispatch_nil_receiver_hot` (0.30x) | Instrumentation-only PGO generation build. |
| 25 | `release-dispatch-c` | Dispatch / behavior | 0.51x | `arc_store_strong_cycle` (1.09x) | `dispatch_nil_receiver_hot` (0.16x) | Uses the C message send path instead of the assembly fast path. |
| 26 | `debug-default` | Modes | 0.38x | `dispatch_nil_receiver_hot` (0.75x) | `arc_retain_release_round_robin` (0.27x) | Debug build with runtime defaults. |
| 27 | `release-sanitize` | Instrumentation | 0.15x | `dispatch_nil_receiver_hot` (0.40x) | `parent_group_cycle` (0.09x) | AddressSanitizer and UndefinedBehaviorSanitizer enabled. |

## Fastest Variant Per Benchmark

| Benchmark | Fastest Variant | Mean | Speedup vs `release-default` |
| --- | --- | --- | --- |
| `dispatch_monomorphic_hot` | `release-max-opt-pgo` | 4.094 ns | 1.32x |
| `dispatch_polymorphic_hot` | `release-max-opt-pgo-bolt` | 4.281 ns | 1.38x |
| `dispatch_nil_receiver_hot` | `release-validation` | 0.431 ns | 1.01x |
| `arc_retain_release_heap` | `release-max-opt-pgo` | 3.155 ns | 2.19x |
| `arc_retain_release_round_robin` | `release-full-lto` | 3.312 ns | 2.86x |
| `arc_store_strong_cycle` | `release-max-opt-pgo` | 4.136 ns | 3.60x |
| `alloc_init_release_plain` | `release-max-opt-pgo-bolt` | 21.451 ns | 1.80x |
| `parent_group_cycle` | `release-full-lto` | 72.668 ns | 1.63x |

## ASM vs C Backend

| Benchmark | ASM Mean | C Mean | ASM Advantage |
| --- | --- | --- | --- |
| `dispatch_monomorphic_hot` | 5.397 ns | 19.838 ns | 3.68x |
| `dispatch_polymorphic_hot` | 5.928 ns | 21.138 ns | 3.57x |
| `dispatch_nil_receiver_hot` | 0.435 ns | 2.781 ns | 6.39x |
| `arc_retain_release_heap` | 6.914 ns | 7.014 ns | 1.01x |
| `arc_retain_release_round_robin` | 9.479 ns | 8.943 ns | 0.94x |
| `arc_store_strong_cycle` | 14.897 ns | 13.678 ns | 0.92x |
| `alloc_init_release_plain` | 38.702 ns | 73.981 ns | 1.91x |
| `parent_group_cycle` | 118.621 ns | 184.220 ns | 1.55x |

## Per-Benchmark Results

### dispatch_monomorphic_hot

| Variant | Mean | Speedup vs `release-default` | Category | Notes |
| --- | --- | --- | --- | --- |
| `debug-default` | 16.373 ns | 0.33x | Modes | Debug build with runtime defaults. |
| `release-default` | 5.397 ns | 1.00x | Modes | Release build with runtime defaults. This is the matrix baseline. |
| `release-native-tuning` | 5.413 ns | 1.00x | Whole-program | Enables -march=native and -mtune=native. |
| `release-thinlto` | 4.834 ns | 1.12x | Whole-program | Enables ThinLTO. |
| `release-full-lto` | 4.527 ns | 1.19x | Whole-program | Enables full LTO. |
| `release-pgo-gen` | 11.708 ns | 0.46x | Instrumentation | Instrumentation-only PGO generation build. |
| `release-pgo-use` | 5.070 ns | 1.06x | Whole-program | Profile-guided optimization on the default release stack. |
| `release-pgo-use-bolt` | 5.134 ns | 1.05x | Whole-program | Default release stack with PGO and BOLT. |
| `release-max-opt` | 4.818 ns | 1.12x | Whole-program | Recommended tuned release stack without profile feedback. |
| `release-max-opt-pgo` | 4.094 ns | 1.32x | Whole-program | Recommended tuned release stack with PGO. |
| `release-max-opt-pgo-bolt` | 4.223 ns | 1.28x | Whole-program | Recommended tuned release stack with PGO and BOLT. |
| `release-dispatch-c` | 19.838 ns | 0.27x | Dispatch / behavior | Uses the C message send path instead of the assembly fast path. |
| `release-dispatch-stats` | 6.093 ns | 0.89x | Dispatch / behavior | Enables dispatch cache statistics counters. |
| `release-forwarding` | 6.021 ns | 0.90x | Dispatch / behavior | Enables forwarding and runtime selector resolution. |
| `release-validation` | 5.299 ns | 1.02x | Dispatch / behavior | Adds defensive object validation checks. |
| `release-tagged-pointers` | 6.376 ns | 0.85x | Dispatch / behavior | Enables tagged pointer support. |
| `release-exceptions-off` | 5.535 ns | 0.98x | Dispatch / behavior | Disables Objective-C exceptions support. |
| `release-reflection-off` | 5.328 ns | 1.01x | Dispatch / behavior | Disables reflection support. |
| `release-dispatch-l0-dual` | 6.163 ns | 0.88x | Dispatch / behavior | Enables the dual-entry L0 dispatch cache. |
| `release-dispatch-cache-2way` | 5.861 ns | 0.92x | Dispatch / behavior | Enables a 2-way dispatch cache. |
| `release-dispatch-cache-negative` | 5.699 ns | 0.95x | Dispatch / behavior | Enables negative cache entries and its 2-way cache prerequisite. |
| `release-compact-headers` | 5.298 ns | 1.02x | Layout / ABI | Uses the compact runtime object header layout. |
| `release-fast-objects` | 5.381 ns | 1.00x | Layout / ABI | Enables FastObject paths and the compact-header prerequisite. |
| `release-inline-value-storage` | 5.340 ns | 1.01x | Layout / ABI | Enables compact inline ValueObject prefixes and the compact-header prerequisite. |
| `release-inline-group-state` | 5.492 ns | 0.98x | Layout / ABI | Stores parent/group bookkeeping inline and enables the compact-header prerequisite. |
| `release-analysis-symbols` | 5.401 ns | 1.00x | Instrumentation | Keeps debug symbols, disables strip, and emits relocations. |
| `release-sanitize` | 45.272 ns | 0.12x | Instrumentation | AddressSanitizer and UndefinedBehaviorSanitizer enabled. |

### dispatch_polymorphic_hot

| Variant | Mean | Speedup vs `release-default` | Category | Notes |
| --- | --- | --- | --- | --- |
| `debug-default` | 20.246 ns | 0.29x | Modes | Debug build with runtime defaults. |
| `release-default` | 5.928 ns | 1.00x | Modes | Release build with runtime defaults. This is the matrix baseline. |
| `release-native-tuning` | 6.098 ns | 0.97x | Whole-program | Enables -march=native and -mtune=native. |
| `release-thinlto` | 5.179 ns | 1.14x | Whole-program | Enables ThinLTO. |
| `release-full-lto` | 5.208 ns | 1.14x | Whole-program | Enables full LTO. |
| `release-pgo-gen` | 16.044 ns | 0.37x | Instrumentation | Instrumentation-only PGO generation build. |
| `release-pgo-use` | 5.585 ns | 1.06x | Whole-program | Profile-guided optimization on the default release stack. |
| `release-pgo-use-bolt` | 12.053 ns | 0.49x | Whole-program | Default release stack with PGO and BOLT. |
| `release-max-opt` | 5.056 ns | 1.17x | Whole-program | Recommended tuned release stack without profile feedback. |
| `release-max-opt-pgo` | 4.322 ns | 1.37x | Whole-program | Recommended tuned release stack with PGO. |
| `release-max-opt-pgo-bolt` | 4.281 ns | 1.38x | Whole-program | Recommended tuned release stack with PGO and BOLT. |
| `release-dispatch-c` | 21.138 ns | 0.28x | Dispatch / behavior | Uses the C message send path instead of the assembly fast path. |
| `release-dispatch-stats` | 10.786 ns | 0.55x | Dispatch / behavior | Enables dispatch cache statistics counters. |
| `release-forwarding` | 6.392 ns | 0.93x | Dispatch / behavior | Enables forwarding and runtime selector resolution. |
| `release-validation` | 5.888 ns | 1.01x | Dispatch / behavior | Adds defensive object validation checks. |
| `release-tagged-pointers` | 7.031 ns | 0.84x | Dispatch / behavior | Enables tagged pointer support. |
| `release-exceptions-off` | 6.155 ns | 0.96x | Dispatch / behavior | Disables Objective-C exceptions support. |
| `release-reflection-off` | 5.896 ns | 1.01x | Dispatch / behavior | Disables reflection support. |
| `release-dispatch-l0-dual` | 6.394 ns | 0.93x | Dispatch / behavior | Enables the dual-entry L0 dispatch cache. |
| `release-dispatch-cache-2way` | 11.357 ns | 0.52x | Dispatch / behavior | Enables a 2-way dispatch cache. |
| `release-dispatch-cache-negative` | 9.455 ns | 0.63x | Dispatch / behavior | Enables negative cache entries and its 2-way cache prerequisite. |
| `release-compact-headers` | 5.960 ns | 0.99x | Layout / ABI | Uses the compact runtime object header layout. |
| `release-fast-objects` | 6.055 ns | 0.98x | Layout / ABI | Enables FastObject paths and the compact-header prerequisite. |
| `release-inline-value-storage` | 5.968 ns | 0.99x | Layout / ABI | Enables compact inline ValueObject prefixes and the compact-header prerequisite. |
| `release-inline-group-state` | 6.040 ns | 0.98x | Layout / ABI | Stores parent/group bookkeeping inline and enables the compact-header prerequisite. |
| `release-analysis-symbols` | 6.054 ns | 0.98x | Instrumentation | Keeps debug symbols, disables strip, and emits relocations. |
| `release-sanitize` | 52.923 ns | 0.11x | Instrumentation | AddressSanitizer and UndefinedBehaviorSanitizer enabled. |

### dispatch_nil_receiver_hot

| Variant | Mean | Speedup vs `release-default` | Category | Notes |
| --- | --- | --- | --- | --- |
| `debug-default` | 0.579 ns | 0.75x | Modes | Debug build with runtime defaults. |
| `release-default` | 0.435 ns | 1.00x | Modes | Release build with runtime defaults. This is the matrix baseline. |
| `release-native-tuning` | 0.439 ns | 0.99x | Whole-program | Enables -march=native and -mtune=native. |
| `release-thinlto` | 0.447 ns | 0.97x | Whole-program | Enables ThinLTO. |
| `release-full-lto` | 0.451 ns | 0.97x | Whole-program | Enables full LTO. |
| `release-pgo-gen` | 1.462 ns | 0.30x | Instrumentation | Instrumentation-only PGO generation build. |
| `release-pgo-use` | 0.433 ns | 1.00x | Whole-program | Profile-guided optimization on the default release stack. |
| `release-pgo-use-bolt` | 0.436 ns | 1.00x | Whole-program | Default release stack with PGO and BOLT. |
| `release-max-opt` | 0.445 ns | 0.98x | Whole-program | Recommended tuned release stack without profile feedback. |
| `release-max-opt-pgo` | 0.434 ns | 1.00x | Whole-program | Recommended tuned release stack with PGO. |
| `release-max-opt-pgo-bolt` | 0.452 ns | 0.96x | Whole-program | Recommended tuned release stack with PGO and BOLT. |
| `release-dispatch-c` | 2.781 ns | 0.16x | Dispatch / behavior | Uses the C message send path instead of the assembly fast path. |
| `release-dispatch-stats` | 0.434 ns | 1.00x | Dispatch / behavior | Enables dispatch cache statistics counters. |
| `release-forwarding` | 0.435 ns | 1.00x | Dispatch / behavior | Enables forwarding and runtime selector resolution. |
| `release-validation` | 0.431 ns | 1.01x | Dispatch / behavior | Adds defensive object validation checks. |
| `release-tagged-pointers` | 0.438 ns | 0.99x | Dispatch / behavior | Enables tagged pointer support. |
| `release-exceptions-off` | 0.453 ns | 0.96x | Dispatch / behavior | Disables Objective-C exceptions support. |
| `release-reflection-off` | 0.433 ns | 1.00x | Dispatch / behavior | Disables reflection support. |
| `release-dispatch-l0-dual` | 0.442 ns | 0.98x | Dispatch / behavior | Enables the dual-entry L0 dispatch cache. |
| `release-dispatch-cache-2way` | 0.436 ns | 1.00x | Dispatch / behavior | Enables a 2-way dispatch cache. |
| `release-dispatch-cache-negative` | 0.634 ns | 0.69x | Dispatch / behavior | Enables negative cache entries and its 2-way cache prerequisite. |
| `release-compact-headers` | 0.439 ns | 0.99x | Layout / ABI | Uses the compact runtime object header layout. |
| `release-fast-objects` | 0.442 ns | 0.98x | Layout / ABI | Enables FastObject paths and the compact-header prerequisite. |
| `release-inline-value-storage` | 0.455 ns | 0.96x | Layout / ABI | Enables compact inline ValueObject prefixes and the compact-header prerequisite. |
| `release-inline-group-state` | 0.440 ns | 0.99x | Layout / ABI | Stores parent/group bookkeeping inline and enables the compact-header prerequisite. |
| `release-analysis-symbols` | 0.441 ns | 0.99x | Instrumentation | Keeps debug symbols, disables strip, and emits relocations. |
| `release-sanitize` | 1.083 ns | 0.40x | Instrumentation | AddressSanitizer and UndefinedBehaviorSanitizer enabled. |

### arc_retain_release_heap

| Variant | Mean | Speedup vs `release-default` | Category | Notes |
| --- | --- | --- | --- | --- |
| `debug-default` | 20.828 ns | 0.33x | Modes | Debug build with runtime defaults. |
| `release-default` | 6.914 ns | 1.00x | Modes | Release build with runtime defaults. This is the matrix baseline. |
| `release-native-tuning` | 7.184 ns | 0.96x | Whole-program | Enables -march=native and -mtune=native. |
| `release-thinlto` | 4.460 ns | 1.55x | Whole-program | Enables ThinLTO. |
| `release-full-lto` | 3.231 ns | 2.14x | Whole-program | Enables full LTO. |
| `release-pgo-gen` | 12.154 ns | 0.57x | Instrumentation | Instrumentation-only PGO generation build. |
| `release-pgo-use` | 4.156 ns | 1.66x | Whole-program | Profile-guided optimization on the default release stack. |
| `release-pgo-use-bolt` | 4.110 ns | 1.68x | Whole-program | Default release stack with PGO and BOLT. |
| `release-max-opt` | 7.147 ns | 0.97x | Whole-program | Recommended tuned release stack without profile feedback. |
| `release-max-opt-pgo` | 3.155 ns | 2.19x | Whole-program | Recommended tuned release stack with PGO. |
| `release-max-opt-pgo-bolt` | 3.369 ns | 2.05x | Whole-program | Recommended tuned release stack with PGO and BOLT. |
| `release-dispatch-c` | 7.014 ns | 0.99x | Dispatch / behavior | Uses the C message send path instead of the assembly fast path. |
| `release-dispatch-stats` | 6.934 ns | 1.00x | Dispatch / behavior | Enables dispatch cache statistics counters. |
| `release-forwarding` | 6.955 ns | 0.99x | Dispatch / behavior | Enables forwarding and runtime selector resolution. |
| `release-validation` | 6.832 ns | 1.01x | Dispatch / behavior | Adds defensive object validation checks. |
| `release-tagged-pointers` | 7.045 ns | 0.98x | Dispatch / behavior | Enables tagged pointer support. |
| `release-exceptions-off` | 6.913 ns | 1.00x | Dispatch / behavior | Disables Objective-C exceptions support. |
| `release-reflection-off` | 6.870 ns | 1.01x | Dispatch / behavior | Disables reflection support. |
| `release-dispatch-l0-dual` | 7.051 ns | 0.98x | Dispatch / behavior | Enables the dual-entry L0 dispatch cache. |
| `release-dispatch-cache-2way` | 7.045 ns | 0.98x | Dispatch / behavior | Enables a 2-way dispatch cache. |
| `release-dispatch-cache-negative` | 7.054 ns | 0.98x | Dispatch / behavior | Enables negative cache entries and its 2-way cache prerequisite. |
| `release-compact-headers` | 7.029 ns | 0.98x | Layout / ABI | Uses the compact runtime object header layout. |
| `release-fast-objects` | 7.079 ns | 0.98x | Layout / ABI | Enables FastObject paths and the compact-header prerequisite. |
| `release-inline-value-storage` | 7.146 ns | 0.97x | Layout / ABI | Enables compact inline ValueObject prefixes and the compact-header prerequisite. |
| `release-inline-group-state` | 7.109 ns | 0.97x | Layout / ABI | Stores parent/group bookkeeping inline and enables the compact-header prerequisite. |
| `release-analysis-symbols` | 6.940 ns | 1.00x | Instrumentation | Keeps debug symbols, disables strip, and emits relocations. |
| `release-sanitize` | 39.849 ns | 0.17x | Instrumentation | AddressSanitizer and UndefinedBehaviorSanitizer enabled. |

### arc_retain_release_round_robin

| Variant | Mean | Speedup vs `release-default` | Category | Notes |
| --- | --- | --- | --- | --- |
| `debug-default` | 35.589 ns | 0.27x | Modes | Debug build with runtime defaults. |
| `release-default` | 9.479 ns | 1.00x | Modes | Release build with runtime defaults. This is the matrix baseline. |
| `release-native-tuning` | 9.974 ns | 0.95x | Whole-program | Enables -march=native and -mtune=native. |
| `release-thinlto` | 4.489 ns | 2.11x | Whole-program | Enables ThinLTO. |
| `release-full-lto` | 3.312 ns | 2.86x | Whole-program | Enables full LTO. |
| `release-pgo-gen` | 12.114 ns | 0.78x | Instrumentation | Instrumentation-only PGO generation build. |
| `release-pgo-use` | 6.291 ns | 1.51x | Whole-program | Profile-guided optimization on the default release stack. |
| `release-pgo-use-bolt` | 6.956 ns | 1.36x | Whole-program | Default release stack with PGO and BOLT. |
| `release-max-opt` | 7.279 ns | 1.30x | Whole-program | Recommended tuned release stack without profile feedback. |
| `release-max-opt-pgo` | 3.660 ns | 2.59x | Whole-program | Recommended tuned release stack with PGO. |
| `release-max-opt-pgo-bolt` | 3.786 ns | 2.50x | Whole-program | Recommended tuned release stack with PGO and BOLT. |
| `release-dispatch-c` | 8.943 ns | 1.06x | Dispatch / behavior | Uses the C message send path instead of the assembly fast path. |
| `release-dispatch-stats` | 9.393 ns | 1.01x | Dispatch / behavior | Enables dispatch cache statistics counters. |
| `release-forwarding` | 9.300 ns | 1.02x | Dispatch / behavior | Enables forwarding and runtime selector resolution. |
| `release-validation` | 8.809 ns | 1.08x | Dispatch / behavior | Adds defensive object validation checks. |
| `release-tagged-pointers` | 16.009 ns | 0.59x | Dispatch / behavior | Enables tagged pointer support. |
| `release-exceptions-off` | 9.844 ns | 0.96x | Dispatch / behavior | Disables Objective-C exceptions support. |
| `release-reflection-off` | 9.742 ns | 0.97x | Dispatch / behavior | Disables reflection support. |
| `release-dispatch-l0-dual` | 10.373 ns | 0.91x | Dispatch / behavior | Enables the dual-entry L0 dispatch cache. |
| `release-dispatch-cache-2way` | 10.115 ns | 0.94x | Dispatch / behavior | Enables a 2-way dispatch cache. |
| `release-dispatch-cache-negative` | 11.216 ns | 0.85x | Dispatch / behavior | Enables negative cache entries and its 2-way cache prerequisite. |
| `release-compact-headers` | 9.503 ns | 1.00x | Layout / ABI | Uses the compact runtime object header layout. |
| `release-fast-objects` | 9.495 ns | 1.00x | Layout / ABI | Enables FastObject paths and the compact-header prerequisite. |
| `release-inline-value-storage` | 9.929 ns | 0.95x | Layout / ABI | Enables compact inline ValueObject prefixes and the compact-header prerequisite. |
| `release-inline-group-state` | 14.867 ns | 0.64x | Layout / ABI | Stores parent/group bookkeeping inline and enables the compact-header prerequisite. |
| `release-analysis-symbols` | 9.641 ns | 0.98x | Instrumentation | Keeps debug symbols, disables strip, and emits relocations. |
| `release-sanitize` | 70.144 ns | 0.14x | Instrumentation | AddressSanitizer and UndefinedBehaviorSanitizer enabled. |

### arc_store_strong_cycle

| Variant | Mean | Speedup vs `release-default` | Category | Notes |
| --- | --- | --- | --- | --- |
| `debug-default` | 32.015 ns | 0.47x | Modes | Debug build with runtime defaults. |
| `release-default` | 14.897 ns | 1.00x | Modes | Release build with runtime defaults. This is the matrix baseline. |
| `release-native-tuning` | 15.133 ns | 0.98x | Whole-program | Enables -march=native and -mtune=native. |
| `release-thinlto` | 4.226 ns | 3.53x | Whole-program | Enables ThinLTO. |
| `release-full-lto` | 4.341 ns | 3.43x | Whole-program | Enables full LTO. |
| `release-pgo-gen` | 17.451 ns | 0.85x | Instrumentation | Instrumentation-only PGO generation build. |
| `release-pgo-use` | 12.152 ns | 1.23x | Whole-program | Profile-guided optimization on the default release stack. |
| `release-pgo-use-bolt` | 11.335 ns | 1.31x | Whole-program | Default release stack with PGO and BOLT. |
| `release-max-opt` | 6.157 ns | 2.42x | Whole-program | Recommended tuned release stack without profile feedback. |
| `release-max-opt-pgo` | 4.136 ns | 3.60x | Whole-program | Recommended tuned release stack with PGO. |
| `release-max-opt-pgo-bolt` | 4.223 ns | 3.53x | Whole-program | Recommended tuned release stack with PGO and BOLT. |
| `release-dispatch-c` | 13.678 ns | 1.09x | Dispatch / behavior | Uses the C message send path instead of the assembly fast path. |
| `release-dispatch-stats` | 14.954 ns | 1.00x | Dispatch / behavior | Enables dispatch cache statistics counters. |
| `release-forwarding` | 18.775 ns | 0.79x | Dispatch / behavior | Enables forwarding and runtime selector resolution. |
| `release-validation` | 15.807 ns | 0.94x | Dispatch / behavior | Adds defensive object validation checks. |
| `release-tagged-pointers` | 16.194 ns | 0.92x | Dispatch / behavior | Enables tagged pointer support. |
| `release-exceptions-off` | 15.559 ns | 0.96x | Dispatch / behavior | Disables Objective-C exceptions support. |
| `release-reflection-off` | 16.340 ns | 0.91x | Dispatch / behavior | Disables reflection support. |
| `release-dispatch-l0-dual` | 14.957 ns | 1.00x | Dispatch / behavior | Enables the dual-entry L0 dispatch cache. |
| `release-dispatch-cache-2way` | 15.089 ns | 0.99x | Dispatch / behavior | Enables a 2-way dispatch cache. |
| `release-dispatch-cache-negative` | 15.012 ns | 0.99x | Dispatch / behavior | Enables negative cache entries and its 2-way cache prerequisite. |
| `release-compact-headers` | 14.885 ns | 1.00x | Layout / ABI | Uses the compact runtime object header layout. |
| `release-fast-objects` | 15.422 ns | 0.97x | Layout / ABI | Enables FastObject paths and the compact-header prerequisite. |
| `release-inline-value-storage` | 15.996 ns | 0.93x | Layout / ABI | Enables compact inline ValueObject prefixes and the compact-header prerequisite. |
| `release-inline-group-state` | 15.214 ns | 0.98x | Layout / ABI | Stores parent/group bookkeeping inline and enables the compact-header prerequisite. |
| `release-analysis-symbols` | 15.091 ns | 0.99x | Instrumentation | Keeps debug symbols, disables strip, and emits relocations. |
| `release-sanitize` | 58.551 ns | 0.25x | Instrumentation | AddressSanitizer and UndefinedBehaviorSanitizer enabled. |

### alloc_init_release_plain

| Variant | Mean | Speedup vs `release-default` | Category | Notes |
| --- | --- | --- | --- | --- |
| `debug-default` | 101.818 ns | 0.38x | Modes | Debug build with runtime defaults. |
| `release-default` | 38.702 ns | 1.00x | Modes | Release build with runtime defaults. This is the matrix baseline. |
| `release-native-tuning` | 39.303 ns | 0.98x | Whole-program | Enables -march=native and -mtune=native. |
| `release-thinlto` | 26.195 ns | 1.48x | Whole-program | Enables ThinLTO. |
| `release-full-lto` | 26.538 ns | 1.46x | Whole-program | Enables full LTO. |
| `release-pgo-gen` | 57.348 ns | 0.67x | Instrumentation | Instrumentation-only PGO generation build. |
| `release-pgo-use` | 33.233 ns | 1.16x | Whole-program | Profile-guided optimization on the default release stack. |
| `release-pgo-use-bolt` | 33.337 ns | 1.16x | Whole-program | Default release stack with PGO and BOLT. |
| `release-max-opt` | 33.484 ns | 1.16x | Whole-program | Recommended tuned release stack without profile feedback. |
| `release-max-opt-pgo` | 21.546 ns | 1.80x | Whole-program | Recommended tuned release stack with PGO. |
| `release-max-opt-pgo-bolt` | 21.451 ns | 1.80x | Whole-program | Recommended tuned release stack with PGO and BOLT. |
| `release-dispatch-c` | 73.981 ns | 0.52x | Dispatch / behavior | Uses the C message send path instead of the assembly fast path. |
| `release-dispatch-stats` | 40.036 ns | 0.97x | Dispatch / behavior | Enables dispatch cache statistics counters. |
| `release-forwarding` | 43.300 ns | 0.89x | Dispatch / behavior | Enables forwarding and runtime selector resolution. |
| `release-validation` | 44.634 ns | 0.87x | Dispatch / behavior | Adds defensive object validation checks. |
| `release-tagged-pointers` | 42.575 ns | 0.91x | Dispatch / behavior | Enables tagged pointer support. |
| `release-exceptions-off` | 37.081 ns | 1.04x | Dispatch / behavior | Disables Objective-C exceptions support. |
| `release-reflection-off` | 39.638 ns | 0.98x | Dispatch / behavior | Disables reflection support. |
| `release-dispatch-l0-dual` | 38.523 ns | 1.00x | Dispatch / behavior | Enables the dual-entry L0 dispatch cache. |
| `release-dispatch-cache-2way` | 39.812 ns | 0.97x | Dispatch / behavior | Enables a 2-way dispatch cache. |
| `release-dispatch-cache-negative` | 39.875 ns | 0.97x | Dispatch / behavior | Enables negative cache entries and its 2-way cache prerequisite. |
| `release-compact-headers` | 41.150 ns | 0.94x | Layout / ABI | Uses the compact runtime object header layout. |
| `release-fast-objects` | 41.942 ns | 0.92x | Layout / ABI | Enables FastObject paths and the compact-header prerequisite. |
| `release-inline-value-storage` | 41.965 ns | 0.92x | Layout / ABI | Enables compact inline ValueObject prefixes and the compact-header prerequisite. |
| `release-inline-group-state` | 40.502 ns | 0.96x | Layout / ABI | Stores parent/group bookkeeping inline and enables the compact-header prerequisite. |
| `release-analysis-symbols` | 39.049 ns | 0.99x | Instrumentation | Keeps debug symbols, disables strip, and emits relocations. |
| `release-sanitize` | 419.776 ns | 0.09x | Instrumentation | AddressSanitizer and UndefinedBehaviorSanitizer enabled. |

### parent_group_cycle

| Variant | Mean | Speedup vs `release-default` | Category | Notes |
| --- | --- | --- | --- | --- |
| `debug-default` | 324.284 ns | 0.37x | Modes | Debug build with runtime defaults. |
| `release-default` | 118.621 ns | 1.00x | Modes | Release build with runtime defaults. This is the matrix baseline. |
| `release-native-tuning` | 134.661 ns | 0.88x | Whole-program | Enables -march=native and -mtune=native. |
| `release-thinlto` | 74.838 ns | 1.59x | Whole-program | Enables ThinLTO. |
| `release-full-lto` | 72.668 ns | 1.63x | Whole-program | Enables full LTO. |
| `release-pgo-gen` | 166.032 ns | 0.71x | Instrumentation | Instrumentation-only PGO generation build. |
| `release-pgo-use` | 103.912 ns | 1.14x | Whole-program | Profile-guided optimization on the default release stack. |
| `release-pgo-use-bolt` | 105.343 ns | 1.13x | Whole-program | Default release stack with PGO and BOLT. |
| `release-max-opt` | 129.043 ns | 0.92x | Whole-program | Recommended tuned release stack without profile feedback. |
| `release-max-opt-pgo` | 101.726 ns | 1.17x | Whole-program | Recommended tuned release stack with PGO. |
| `release-max-opt-pgo-bolt` | 94.103 ns | 1.26x | Whole-program | Recommended tuned release stack with PGO and BOLT. |
| `release-dispatch-c` | 184.220 ns | 0.64x | Dispatch / behavior | Uses the C message send path instead of the assembly fast path. |
| `release-dispatch-stats` | 122.531 ns | 0.97x | Dispatch / behavior | Enables dispatch cache statistics counters. |
| `release-forwarding` | 122.910 ns | 0.97x | Dispatch / behavior | Enables forwarding and runtime selector resolution. |
| `release-validation` | 126.226 ns | 0.94x | Dispatch / behavior | Adds defensive object validation checks. |
| `release-tagged-pointers` | 120.721 ns | 0.98x | Dispatch / behavior | Enables tagged pointer support. |
| `release-exceptions-off` | 116.144 ns | 1.02x | Dispatch / behavior | Disables Objective-C exceptions support. |
| `release-reflection-off` | 121.418 ns | 0.98x | Dispatch / behavior | Disables reflection support. |
| `release-dispatch-l0-dual` | 121.488 ns | 0.98x | Dispatch / behavior | Enables the dual-entry L0 dispatch cache. |
| `release-dispatch-cache-2way` | 125.821 ns | 0.94x | Dispatch / behavior | Enables a 2-way dispatch cache. |
| `release-dispatch-cache-negative` | 119.574 ns | 0.99x | Dispatch / behavior | Enables negative cache entries and its 2-way cache prerequisite. |
| `release-compact-headers` | 157.854 ns | 0.75x | Layout / ABI | Uses the compact runtime object header layout. |
| `release-fast-objects` | 159.007 ns | 0.75x | Layout / ABI | Enables FastObject paths and the compact-header prerequisite. |
| `release-inline-value-storage` | 208.288 ns | 0.57x | Layout / ABI | Enables compact inline ValueObject prefixes and the compact-header prerequisite. |
| `release-inline-group-state` | 142.204 ns | 0.83x | Layout / ABI | Stores parent/group bookkeeping inline and enables the compact-header prerequisite. |
| `release-analysis-symbols` | 120.743 ns | 0.98x | Instrumentation | Keeps debug symbols, disables strip, and emits relocations. |
| `release-sanitize` | 1374.956 ns | 0.09x | Instrumentation | AddressSanitizer and UndefinedBehaviorSanitizer enabled. |

## Failed Variants

- `release-threadsafe`: `src/runtime/dispatch_x86_64.asm:198:43: error: unknown token in expression`

## Baseline Reference

`release-default` artifacts: `/workspaces/smallfw/build/runtime-analysis/performance-matrix/runs/release-default`
