# Runtime Performance Matrix (Curated)

This document is generated from measured `xmake run-runtime-bench` runs on the current host.
The curated matrix focuses on the tuned release-oriented variants, including PGO and BOLT rows.
Relative speedups are computed against the matching mode baseline inside the same ABI: `debug-default` for debug rows and `release-default` for release rows.

Generated at: `2026-03-13T15:02:55Z`
Regenerate with: `xmake run-runtime-performance-matrix --matrix=curated --samples=1 --warmups=1 --objc-runtimes=both --outdir=build/runtime-analysis/performance-matrix-curated-v3-fixed --doc=docs/PERFORMANCE.md`

## Environment

- Host: `linux`
- Architecture: `x86_64`
- Objective-C runtimes benchmarked: `gnustep-2.3`, `objfw-1.5`
- `uname -srvm`: `Linux 6.17.7-ba25.fc43.x86_64 #1 SMP PREEMPT_DYNAMIC Mon Jan 19 05:47:43 UTC 2026 x86_64`
- `clang --version`: `Debian clang version 21.1.8 (++20251221033036+2078da43e25a-1~exp1~20251221153213.50)`
- `xmake --version`: `xmake v3.0.7+dev.f9d6d50, A cross-platform build utility based on Lua`
- Samples per variant: `1`
- Warmups per variant: `1`
- Benchmark artifact root: `/workspaces/smallfw/build/runtime-analysis/performance-matrix-curated-v3-fixed`

## Methodology

- Summary tables report sample means in nanoseconds.
- Geometric means are computed from per-benchmark speedups against the matching ABI+mode baseline.
- Detailed `median`, `min`, `max`, and `stdev` values are preserved in `matrix.json` and each variant `summary.json`.
- `runtime-bench` pins execution to CPU 0 via `taskset` when available.

## Coverage

- Matrix kind: `curated`
- Variants attempted: `38`
- Variants completed: `38`
- Variants failed: `0`
- Benchmarks: `dispatch_monomorphic_hot`, `dispatch_polymorphic_hot`, `arc_retain_release_heap`, `arc_retain_release_round_robin`, `arc_store_strong_cycle`, `alloc_init_release_plain`, `parent_group_cycle`

## Variant Definitions

| Variant | ABI | Category | Mode | PGO | BOLT | Changed Options | Status | Failure | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `release-default` | `gnustep-2.3` | Modes | `release` | `off` | `off` | `objc-runtime=gnustep-2.3` | ok | - | Release build with runtime defaults. This is the matrix baseline. |
| `release-default` | `objfw-1.5` | Modes | `release` | `off` | `off` | `objc-runtime=objfw-1.5` | ok | - | Release build with runtime defaults. This is the matrix baseline. |
| `release-native-tuning` | `gnustep-2.3` | Whole-program | `release` | `off` | `off` | `objc-runtime=gnustep-2.3`, `runtime-native-tuning=y` | ok | - | Enables -march=native and -mtune=native. |
| `release-native-tuning` | `objfw-1.5` | Whole-program | `release` | `off` | `off` | `objc-runtime=objfw-1.5`, `runtime-native-tuning=y` | ok | - | Enables -march=native and -mtune=native. |
| `release-thinlto` | `gnustep-2.3` | Whole-program | `release` | `off` | `off` | `objc-runtime=gnustep-2.3`, `runtime-thinlto=y` | ok | - | Enables ThinLTO. |
| `release-thinlto` | `objfw-1.5` | Whole-program | `release` | `off` | `off` | `objc-runtime=objfw-1.5`, `runtime-thinlto=y` | ok | - | Enables ThinLTO. |
| `release-full-lto` | `gnustep-2.3` | Whole-program | `release` | `off` | `off` | `objc-runtime=gnustep-2.3`, `runtime-full-lto=y` | ok | - | Enables full LTO. |
| `release-full-lto` | `objfw-1.5` | Whole-program | `release` | `off` | `off` | `objc-runtime=objfw-1.5`, `runtime-full-lto=y` | ok | - | Enables full LTO. |
| `release-pgo-gen` | `gnustep-2.3` | Instrumentation | `release` | `gen` | `off` | `objc-runtime=gnustep-2.3` | ok | - | Instrumentation-only PGO generation build. |
| `release-pgo-gen` | `objfw-1.5` | Instrumentation | `release` | `gen` | `off` | `objc-runtime=objfw-1.5` | ok | - | Instrumentation-only PGO generation build. |
| `release-pgo-use` | `gnustep-2.3` | Whole-program | `release` | `use` | `off` | `objc-runtime=gnustep-2.3` | ok | - | Profile-guided optimization on the default release stack. |
| `release-pgo-use` | `objfw-1.5` | Whole-program | `release` | `use` | `off` | `objc-runtime=objfw-1.5` | ok | - | Profile-guided optimization on the default release stack. |
| `release-pgo-use-bolt` | `gnustep-2.3` | Whole-program | `release` | `use` | `on` | `analysis-symbols=y`, `objc-runtime=gnustep-2.3` | ok | - | Default release stack with PGO and BOLT. |
| `release-pgo-use-bolt` | `objfw-1.5` | Whole-program | `release` | `use` | `on` | `analysis-symbols=y`, `objc-runtime=objfw-1.5` | ok | - | Default release stack with PGO and BOLT. |
| `release-full-lto-pgo` | `gnustep-2.3` | Whole-program | `release` | `use` | `off` | `objc-runtime=gnustep-2.3`, `runtime-full-lto=y` | ok | - | Measured best whole-program stack without native tuning. |
| `release-full-lto-pgo` | `objfw-1.5` | Whole-program | `release` | `use` | `off` | `objc-runtime=objfw-1.5`, `runtime-full-lto=y` | ok | - | Measured best whole-program stack without native tuning. |
| `release-full-lto-native-pgo-bolt` | `gnustep-2.3` | Whole-program | `release` | `use` | `on` | `analysis-symbols=y`, `objc-runtime=gnustep-2.3`, `runtime-native-tuning=y`, `runtime-full-lto=y` | ok | - | Measured fastest release stack on Linux x86_64: full LTO, native tuning, PGO, and BOLT. |
| `release-full-lto-native-pgo-bolt` | `objfw-1.5` | Whole-program | `release` | `use` | `on` | `analysis-symbols=y`, `objc-runtime=objfw-1.5`, `runtime-native-tuning=y`, `runtime-full-lto=y` | ok | - | Measured fastest release stack on Linux x86_64: full LTO, native tuning, PGO, and BOLT. |
| `release-dispatch-c` | `gnustep-2.3` | Dispatch / behavior | `release` | `off` | `off` | `objc-runtime=gnustep-2.3`, `dispatch-backend=c` | ok | - | Uses the C message send path instead of the assembly fast path. |
| `release-dispatch-c` | `objfw-1.5` | Dispatch / behavior | `release` | `off` | `off` | `objc-runtime=objfw-1.5`, `dispatch-backend=c` | ok | - | Uses the C message send path instead of the assembly fast path. |
| `release-forwarding` | `gnustep-2.3` | Dispatch / behavior | `release` | `off` | `off` | `objc-runtime=gnustep-2.3`, `runtime-forwarding=y` | ok | - | Enables forwarding and the cold miss path. |
| `release-forwarding` | `objfw-1.5` | Dispatch / behavior | `release` | `off` | `off` | `objc-runtime=objfw-1.5`, `runtime-forwarding=y` | ok | - | Enables forwarding and the cold miss path. |
| `release-validation` | `gnustep-2.3` | Dispatch / behavior | `release` | `off` | `off` | `objc-runtime=gnustep-2.3`, `runtime-validation=y` | ok | - | Adds defensive object validation checks. |
| `release-validation` | `objfw-1.5` | Dispatch / behavior | `release` | `off` | `off` | `objc-runtime=objfw-1.5`, `runtime-validation=y` | ok | - | Adds defensive object validation checks. |
| `release-tagged-pointers` | `gnustep-2.3` | Dispatch / behavior | `release` | `off` | `off` | `objc-runtime=gnustep-2.3`, `runtime-tagged-pointers=y` | ok | - | Enables tagged pointer support. |
| `release-tagged-pointers` | `objfw-1.5` | Dispatch / behavior | `release` | `off` | `off` | `objc-runtime=objfw-1.5`, `runtime-tagged-pointers=y` | ok | - | Enables tagged pointer support. |
| `release-exceptions-off` | `gnustep-2.3` | Dispatch / behavior | `release` | `off` | `off` | `objc-runtime=gnustep-2.3`, `runtime-exceptions=n` | ok | - | Disables Objective-C exceptions support. |
| `release-exceptions-off` | `objfw-1.5` | Dispatch / behavior | `release` | `off` | `off` | `objc-runtime=objfw-1.5`, `runtime-exceptions=n` | ok | - | Disables Objective-C exceptions support. |
| `release-reflection-off` | `gnustep-2.3` | Dispatch / behavior | `release` | `off` | `off` | `objc-runtime=gnustep-2.3`, `runtime-reflection=n` | ok | - | Disables reflection support. |
| `release-reflection-off` | `objfw-1.5` | Dispatch / behavior | `release` | `off` | `off` | `objc-runtime=objfw-1.5`, `runtime-reflection=n` | ok | - | Disables reflection support. |
| `release-compact-headers` | `gnustep-2.3` | Layout / ABI | `release` | `off` | `off` | `objc-runtime=gnustep-2.3`, `runtime-compact-headers=y` | ok | - | Uses the compact runtime object header layout. |
| `release-compact-headers` | `objfw-1.5` | Layout / ABI | `release` | `off` | `off` | `objc-runtime=objfw-1.5`, `runtime-compact-headers=y` | ok | - | Uses the compact runtime object header layout. |
| `release-inline-value-storage` | `gnustep-2.3` | Layout / ABI | `release` | `off` | `off` | `objc-runtime=gnustep-2.3`, `runtime-compact-headers=y`, `runtime-inline-value-storage=y` | ok | - | Enables compact inline ValueObject prefixes and the compact-header prerequisite. |
| `release-inline-value-storage` | `objfw-1.5` | Layout / ABI | `release` | `off` | `off` | `objc-runtime=objfw-1.5`, `runtime-compact-headers=y`, `runtime-inline-value-storage=y` | ok | - | Enables compact inline ValueObject prefixes and the compact-header prerequisite. |
| `release-inline-group-state` | `gnustep-2.3` | Layout / ABI | `release` | `off` | `off` | `objc-runtime=gnustep-2.3`, `runtime-compact-headers=y`, `runtime-inline-group-state=y` | ok | - | Stores parent/group bookkeeping inline and enables the compact-header prerequisite. |
| `release-inline-group-state` | `objfw-1.5` | Layout / ABI | `release` | `off` | `off` | `objc-runtime=objfw-1.5`, `runtime-compact-headers=y`, `runtime-inline-group-state=y` | ok | - | Stores parent/group bookkeeping inline and enables the compact-header prerequisite. |
| `release-analysis-symbols` | `gnustep-2.3` | Instrumentation | `release` | `off` | `off` | `analysis-symbols=y`, `objc-runtime=gnustep-2.3` | ok | - | Keeps debug symbols, disables strip, and emits relocations. |
| `release-analysis-symbols` | `objfw-1.5` | Instrumentation | `release` | `off` | `off` | `analysis-symbols=y`, `objc-runtime=objfw-1.5` | ok | - | Keeps debug symbols, disables strip, and emits relocations. |

## Leaderboard

### GNUstep ABI Release

| Rank | Variant | Category | Geo Mean vs ABI `release-default` | Best Case | Worst Case | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | `release-full-lto-native-pgo-bolt` | Whole-program | 1.86x | `parent_group_cycle` (3.38x) | `dispatch_polymorphic_hot` (0.94x) | Measured fastest release stack on Linux x86_64: full LTO, native tuning, PGO, and BOLT. |
| 2 | `release-full-lto-pgo` | Whole-program | 1.83x | `parent_group_cycle` (3.00x) | `dispatch_polymorphic_hot` (1.02x) | Measured best whole-program stack without native tuning. |
| 3 | `release-thinlto` | Whole-program | 1.51x | `arc_retain_release_heap` (2.46x) | `dispatch_polymorphic_hot` (0.91x) | Enables ThinLTO. |
| 4 | `release-full-lto` | Whole-program | 1.50x | `arc_retain_release_heap` (2.39x) | `dispatch_polymorphic_hot` (0.91x) | Enables full LTO. |
| 5 | `release-pgo-use-bolt` | Whole-program | 1.22x | `parent_group_cycle` (1.63x) | `dispatch_monomorphic_hot` (0.99x) | Default release stack with PGO and BOLT. |
| 6 | `release-pgo-use` | Whole-program | 1.15x | `arc_retain_release_heap` (1.41x) | `dispatch_polymorphic_hot` (0.94x) | Profile-guided optimization on the default release stack. |
| 7 | `release-analysis-symbols` | Instrumentation | 1.01x | `parent_group_cycle` (1.04x) | `arc_retain_release_heap` (0.98x) | Keeps debug symbols, disables strip, and emits relocations. |
| 8 | `release-reflection-off` | Dispatch / behavior | 1.00x | `parent_group_cycle` (1.04x) | `arc_retain_release_heap` (0.98x) | Disables reflection support. |
| 9 | `release-exceptions-off` | Dispatch / behavior | 1.00x | `parent_group_cycle` (1.07x) | `arc_store_strong_cycle` (0.93x) | Disables Objective-C exceptions support. |
| 10 | `release-default` | Modes | 1.00x | `dispatch_monomorphic_hot` (1.00x) | `dispatch_monomorphic_hot` (1.00x) | Release build with runtime defaults. This is the matrix baseline. |
| 11 | `release-forwarding` | Dispatch / behavior | 0.99x | `alloc_init_release_plain` (1.02x) | `dispatch_polymorphic_hot` (0.92x) | Enables forwarding and the cold miss path. |
| 12 | `release-validation` | Dispatch / behavior | 0.98x | `arc_retain_release_round_robin` (1.18x) | `alloc_init_release_plain` (0.77x) | Adds defensive object validation checks. |
| 13 | `release-native-tuning` | Whole-program | 0.98x | `parent_group_cycle` (1.00x) | `alloc_init_release_plain` (0.95x) | Enables -march=native and -mtune=native. |
| 14 | `release-inline-group-state` | Layout / ABI | 0.96x | `arc_retain_release_heap` (1.02x) | `alloc_init_release_plain` (0.88x) | Stores parent/group bookkeeping inline and enables the compact-header prerequisite. |
| 15 | `release-compact-headers` | Layout / ABI | 0.94x | `arc_retain_release_heap` (1.02x) | `parent_group_cycle` (0.77x) | Uses the compact runtime object header layout. |
| 16 | `release-inline-value-storage` | Layout / ABI | 0.90x | `arc_retain_release_heap` (1.03x) | `parent_group_cycle` (0.64x) | Enables compact inline ValueObject prefixes and the compact-header prerequisite. |
| 17 | `release-tagged-pointers` | Dispatch / behavior | 0.90x | `parent_group_cycle` (0.98x) | `arc_retain_release_heap` (0.84x) | Enables tagged pointer support. |
| 18 | `release-pgo-gen` | Instrumentation | 0.52x | `arc_retain_release_heap` (0.70x) | `arc_store_strong_cycle` (0.36x) | Instrumentation-only PGO generation build. |
| 19 | `release-dispatch-c` | Dispatch / behavior | 0.26x | `arc_retain_release_heap` (1.07x) | `dispatch_monomorphic_hot` (0.03x) | Uses the C message send path instead of the assembly fast path. |

### ObjFW ABI Release

| Rank | Variant | Category | Geo Mean vs ABI `release-default` | Best Case | Worst Case | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | `release-full-lto-pgo` | Whole-program | 1.88x | `dispatch_polymorphic_hot` (2.94x) | `dispatch_monomorphic_hot` (1.37x) | Measured best whole-program stack without native tuning. |
| 2 | `release-full-lto` | Whole-program | 1.64x | `dispatch_polymorphic_hot` (2.52x) | `dispatch_monomorphic_hot` (1.19x) | Enables full LTO. |
| 3 | `release-full-lto-native-pgo-bolt` | Whole-program | 1.60x | `arc_retain_release_heap` (2.59x) | `dispatch_polymorphic_hot` (0.93x) | Measured fastest release stack on Linux x86_64: full LTO, native tuning, PGO, and BOLT. |
| 4 | `release-thinlto` | Whole-program | 1.32x | `dispatch_polymorphic_hot` (2.59x) | `arc_retain_release_heap` (0.74x) | Enables ThinLTO. |
| 5 | `release-pgo-use` | Whole-program | 1.30x | `dispatch_polymorphic_hot` (2.40x) | `arc_store_strong_cycle` (1.03x) | Profile-guided optimization on the default release stack. |
| 6 | `release-exceptions-off` | Dispatch / behavior | 1.10x | `dispatch_polymorphic_hot` (2.20x) | `arc_store_strong_cycle` (0.82x) | Disables Objective-C exceptions support. |
| 7 | `release-pgo-use-bolt` | Whole-program | 1.05x | `parent_group_cycle` (1.27x) | `arc_store_strong_cycle` (0.91x) | Default release stack with PGO and BOLT. |
| 8 | `release-native-tuning` | Whole-program | 1.01x | `dispatch_polymorphic_hot` (1.77x) | `dispatch_monomorphic_hot` (0.79x) | Enables -march=native and -mtune=native. |
| 9 | `release-default` | Modes | 1.00x | `dispatch_monomorphic_hot` (1.00x) | `dispatch_monomorphic_hot` (1.00x) | Release build with runtime defaults. This is the matrix baseline. |
| 10 | `release-analysis-symbols` | Instrumentation | 1.00x | `parent_group_cycle` (1.02x) | `dispatch_polymorphic_hot` (0.96x) | Keeps debug symbols, disables strip, and emits relocations. |
| 11 | `release-reflection-off` | Dispatch / behavior | 0.99x | `dispatch_polymorphic_hot` (1.02x) | `alloc_init_release_plain` (0.97x) | Disables reflection support. |
| 12 | `release-dispatch-c` | Dispatch / behavior | 0.98x | `arc_retain_release_heap` (1.01x) | `dispatch_polymorphic_hot` (0.95x) | Uses the C message send path instead of the assembly fast path. |
| 13 | `release-forwarding` | Dispatch / behavior | 0.97x | `dispatch_polymorphic_hot` (1.70x) | `dispatch_monomorphic_hot` (0.75x) | Enables forwarding and the cold miss path. |
| 14 | `release-tagged-pointers` | Dispatch / behavior | 0.92x | `dispatch_polymorphic_hot` (2.03x) | `arc_store_strong_cycle` (0.68x) | Enables tagged pointer support. |
| 15 | `release-inline-value-storage` | Layout / ABI | 0.91x | `dispatch_polymorphic_hot` (1.31x) | `parent_group_cycle` (0.65x) | Enables compact inline ValueObject prefixes and the compact-header prerequisite. |
| 16 | `release-validation` | Dispatch / behavior | 0.91x | `arc_retain_release_heap` (1.05x) | `arc_store_strong_cycle` (0.72x) | Adds defensive object validation checks. |
| 17 | `release-inline-group-state` | Layout / ABI | 0.89x | `arc_retain_release_heap` (0.97x) | `dispatch_polymorphic_hot` (0.77x) | Stores parent/group bookkeeping inline and enables the compact-header prerequisite. |
| 18 | `release-compact-headers` | Layout / ABI | 0.87x | `arc_retain_release_heap` (0.94x) | `parent_group_cycle` (0.76x) | Uses the compact runtime object header layout. |
| 19 | `release-pgo-gen` | Instrumentation | 0.59x | `dispatch_polymorphic_hot` (1.25x) | `arc_store_strong_cycle` (0.34x) | Instrumentation-only PGO generation build. |

## ObjFW vs GNUstep

### Release

| Variant | ObjFW vs GNUstep | Winner | Best ObjFW Case | Worst ObjFW Case | Notes |
| --- | --- | --- | --- | --- | --- |
| `release-dispatch-c` | 1.57x | ObjFW ABI | `dispatch_monomorphic_hot` (3.37x) | `arc_retain_release_heap` (0.99x) | Uses the C message send path instead of the assembly fast path. |
| `release-pgo-gen` | 0.47x | GNUstep ABI | `arc_store_strong_cycle` (1.11x) | `dispatch_polymorphic_hot` (0.12x) | Instrumentation-only PGO generation build. |
| `release-pgo-use` | 0.47x | GNUstep ABI | `arc_store_strong_cycle` (1.10x) | `dispatch_monomorphic_hot` (0.10x) | Profile-guided optimization on the default release stack. |
| `release-exceptions-off` | 0.45x | GNUstep ABI | `arc_retain_release_round_robin` (1.11x) | `dispatch_monomorphic_hot` (0.09x) | Disables Objective-C exceptions support. |
| `release-full-lto` | 0.45x | GNUstep ABI | `arc_retain_release_heap` (1.02x) | `dispatch_monomorphic_hot` (0.11x) | Enables full LTO. |
| `release-native-tuning` | 0.43x | GNUstep ABI | `arc_store_strong_cycle` (1.03x) | `dispatch_monomorphic_hot` (0.07x) | Enables -march=native and -mtune=native. |
| `release-full-lto-pgo` | 0.42x | GNUstep ABI | `arc_retain_release_heap` (0.95x) | `dispatch_polymorphic_hot` (0.12x) | Measured best whole-program stack without native tuning. |
| `release-tagged-pointers` | 0.42x | GNUstep ABI | `arc_retain_release_heap` (0.93x) | `dispatch_polymorphic_hot` (0.09x) | Enables tagged pointer support. |
| `release-inline-value-storage` | 0.42x | GNUstep ABI | `arc_store_strong_cycle` (1.09x) | `dispatch_polymorphic_hot` (0.05x) | Enables compact inline ValueObject prefixes and the compact-header prerequisite. |
| `release-default` | 0.41x | GNUstep ABI | `arc_store_strong_cycle` (1.17x) | `dispatch_polymorphic_hot` (0.04x) | Release build with runtime defaults. This is the matrix baseline. |
| `release-analysis-symbols` | 0.41x | GNUstep ABI | `arc_store_strong_cycle` (1.16x) | `dispatch_polymorphic_hot` (0.04x) | Keeps debug symbols, disables strip, and emits relocations. |
| `release-reflection-off` | 0.41x | GNUstep ABI | `arc_store_strong_cycle` (1.16x) | `dispatch_polymorphic_hot` (0.04x) | Disables reflection support. |
| `release-forwarding` | 0.41x | GNUstep ABI | `arc_retain_release_heap` (1.07x) | `dispatch_monomorphic_hot` (0.07x) | Enables forwarding and the cold miss path. |
| `release-validation` | 0.38x | GNUstep ABI | `arc_retain_release_heap` (0.99x) | `dispatch_polymorphic_hot` (0.04x) | Adds defensive object validation checks. |
| `release-inline-group-state` | 0.38x | GNUstep ABI | `arc_store_strong_cycle` (1.05x) | `dispatch_polymorphic_hot` (0.03x) | Stores parent/group bookkeeping inline and enables the compact-header prerequisite. |
| `release-compact-headers` | 0.38x | GNUstep ABI | `arc_store_strong_cycle` (0.96x) | `dispatch_polymorphic_hot` (0.04x) | Uses the compact runtime object header layout. |
| `release-thinlto` | 0.36x | GNUstep ABI | `arc_store_strong_cycle` (0.95x) | `dispatch_monomorphic_hot` (0.11x) | Enables ThinLTO. |
| `release-full-lto-native-pgo-bolt` | 0.36x | GNUstep ABI | `arc_retain_release_round_robin` (1.01x) | `dispatch_polymorphic_hot` (0.04x) | Measured fastest release stack on Linux x86_64: full LTO, native tuning, PGO, and BOLT. |
| `release-pgo-use-bolt` | 0.35x | GNUstep ABI | `arc_retain_release_round_robin` (0.87x) | `dispatch_polymorphic_hot` (0.04x) | Default release stack with PGO and BOLT. |

## Fastest Variant Per Benchmark

| Benchmark | Fastest Variant | Mode | ABI | Mean | Speedup vs matching baseline |
| --- | --- | --- | --- | --- | --- |
| `dispatch_monomorphic_hot` | `release-full-lto-pgo` | `release` | GNUstep ABI | 0.577 ns | 1.03x |
| `dispatch_polymorphic_hot` | `release-full-lto-pgo` | `release` | GNUstep ABI | 0.623 ns | 1.02x |
| `arc_retain_release_heap` | `release-full-lto-pgo` | `release` | GNUstep ABI | 2.039 ns | 2.73x |
| `arc_retain_release_round_robin` | `release-full-lto-native-pgo-bolt` | `release` | ObjFW ABI | 2.688 ns | 2.26x |
| `arc_store_strong_cycle` | `release-full-lto-pgo` | `release` | GNUstep ABI | 4.302 ns | 1.76x |
| `alloc_init_release_plain` | `release-full-lto-native-pgo-bolt` | `release` | GNUstep ABI | 7.818 ns | 2.16x |
| `parent_group_cycle` | `release-full-lto-native-pgo-bolt` | `release` | GNUstep ABI | 26.135 ns | 3.38x |

## ASM vs C Backend

| ABI | Mode | Benchmark | ASM Mean | C Mean | ASM Advantage |
| --- | --- | --- | --- | --- | --- |
| GNUstep ABI | `release` | `dispatch_monomorphic_hot` | 0.596 ns | 21.687 ns | 36.39x |
| GNUstep ABI | `release` | `dispatch_polymorphic_hot` | 0.633 ns | 22.000 ns | 34.76x |
| GNUstep ABI | `release` | `arc_retain_release_heap` | 5.576 ns | 5.227 ns | 0.94x |
| GNUstep ABI | `release` | `arc_retain_release_round_robin` | 6.212 ns | 6.284 ns | 1.01x |
| GNUstep ABI | `release` | `arc_store_strong_cycle` | 7.561 ns | 8.046 ns | 1.06x |
| GNUstep ABI | `release` | `alloc_init_release_plain` | 16.911 ns | 78.041 ns | 4.61x |
| GNUstep ABI | `release` | `parent_group_cycle` | 88.409 ns | 190.378 ns | 2.15x |
| ObjFW ABI | `release` | `dispatch_monomorphic_hot` | 6.394 ns | 6.431 ns | 1.01x |
| ObjFW ABI | `release` | `dispatch_polymorphic_hot` | 15.132 ns | 15.912 ns | 1.05x |
| ObjFW ABI | `release` | `arc_retain_release_heap` | 5.302 ns | 5.258 ns | 0.99x |
| ObjFW ABI | `release` | `arc_retain_release_round_robin` | 6.076 ns | 6.177 ns | 1.02x |
| ObjFW ABI | `release` | `arc_store_strong_cycle` | 6.475 ns | 6.616 ns | 1.02x |
| ObjFW ABI | `release` | `alloc_init_release_plain` | 30.825 ns | 31.300 ns | 1.02x |
| ObjFW ABI | `release` | `parent_group_cycle` | 115.943 ns | 116.887 ns | 1.01x |

## Detailed Matrix

### GNUstep ABI Release

| Variant | Category | Geo Mean vs `release-default` | dispatch_monomorphic_hot | dispatch_polymorphic_hot | arc_retain_release_heap | arc_retain_release_round_robin | arc_store_strong_cycle | alloc_init_release_plain | parent_group_cycle | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `release-default` | Modes | 1.00x | 0.596 ns | 0.633 ns | 5.576 ns | 6.212 ns | 7.561 ns | 16.911 ns | 88.409 ns | Release build with runtime defaults. This is the matrix baseline. |
| `release-native-tuning` | Whole-program | 0.98x | 0.598 ns | 0.651 ns | 5.708 ns | 6.439 ns | 7.750 ns | 17.736 ns | 88.487 ns | Enables -march=native and -mtune=native. |
| `release-thinlto` | Whole-program | 1.51x | 0.592 ns | 0.695 ns | 2.271 ns | 3.002 ns | 4.695 ns | 11.919 ns | 51.508 ns | Enables ThinLTO. |
| `release-full-lto` | Whole-program | 1.50x | 0.596 ns | 0.695 ns | 2.329 ns | 3.086 ns | 4.741 ns | 11.884 ns | 52.487 ns | Enables full LTO. |
| `release-pgo-gen` | Instrumentation | 0.52x | 1.442 ns | 1.424 ns | 7.973 ns | 10.152 ns | 20.846 ns | 25.745 ns | 163.331 ns | Instrumentation-only PGO generation build. |
| `release-pgo-use` | Whole-program | 1.15x | 0.593 ns | 0.671 ns | 3.965 ns | 5.330 ns | 6.950 ns | 14.692 ns | 64.599 ns | Profile-guided optimization on the default release stack. |
| `release-pgo-use-bolt` | Whole-program | 1.22x | 0.600 ns | 0.635 ns | 4.439 ns | 4.886 ns | 6.122 ns | 13.031 ns | 54.214 ns | Default release stack with PGO and BOLT. |
| `release-full-lto-pgo` | Whole-program | 1.83x | 0.577 ns | 0.623 ns | 2.039 ns | 2.715 ns | 4.302 ns | 8.376 ns | 29.475 ns | Measured best whole-program stack without native tuning. |
| `release-full-lto-native-pgo-bolt` | Whole-program | 1.86x | 0.593 ns | 0.671 ns | 2.039 ns | 2.706 ns | 4.313 ns | 7.818 ns | 26.135 ns | Measured fastest release stack on Linux x86_64: full LTO, native tuning, PGO, and BOLT. |
| `release-dispatch-c` | Dispatch / behavior | 0.26x | 21.687 ns | 22.000 ns | 5.227 ns | 6.284 ns | 8.046 ns | 78.041 ns | 190.378 ns | Uses the C message send path instead of the assembly fast path. |
| `release-forwarding` | Dispatch / behavior | 0.99x | 0.613 ns | 0.691 ns | 5.704 ns | 6.103 ns | 7.421 ns | 16.535 ns | 89.160 ns | Enables forwarding and the cold miss path. |
| `release-validation` | Dispatch / behavior | 0.98x | 0.594 ns | 0.631 ns | 5.022 ns | 5.272 ns | 8.137 ns | 21.900 ns | 97.957 ns | Adds defensive object validation checks. |
| `release-tagged-pointers` | Dispatch / behavior | 0.90x | 0.704 ns | 0.707 ns | 6.671 ns | 6.533 ns | 7.819 ns | 19.547 ns | 90.502 ns | Enables tagged pointer support. |
| `release-exceptions-off` | Dispatch / behavior | 1.00x | 0.597 ns | 0.647 ns | 5.290 ns | 6.286 ns | 8.093 ns | 16.775 ns | 82.893 ns | Disables Objective-C exceptions support. |
| `release-reflection-off` | Dispatch / behavior | 1.00x | 0.601 ns | 0.628 ns | 5.691 ns | 6.205 ns | 7.559 ns | 16.675 ns | 85.110 ns | Disables reflection support. |
| `release-compact-headers` | Layout / ABI | 0.94x | 0.586 ns | 0.658 ns | 5.452 ns | 6.146 ns | 7.843 ns | 19.173 ns | 114.876 ns | Uses the compact runtime object header layout. |
| `release-inline-value-storage` | Layout / ABI | 0.90x | 0.590 ns | 0.632 ns | 5.439 ns | 6.394 ns | 8.537 ns | 19.561 ns | 138.121 ns | Enables compact inline ValueObject prefixes and the compact-header prerequisite. |
| `release-inline-group-state` | Layout / ABI | 0.96x | 0.590 ns | 0.642 ns | 5.460 ns | 6.235 ns | 8.040 ns | 19.127 ns | 99.956 ns | Stores parent/group bookkeeping inline and enables the compact-header prerequisite. |
| `release-analysis-symbols` | Instrumentation | 1.01x | 0.585 ns | 0.629 ns | 5.676 ns | 6.262 ns | 7.518 ns | 16.945 ns | 85.046 ns | Keeps debug symbols, disables strip, and emits relocations. |

### ObjFW ABI Release

| Variant | Category | Geo Mean vs `release-default` | dispatch_monomorphic_hot | dispatch_polymorphic_hot | arc_retain_release_heap | arc_retain_release_round_robin | arc_store_strong_cycle | alloc_init_release_plain | parent_group_cycle | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `release-default` | Modes | 1.00x | 6.394 ns | 15.132 ns | 5.302 ns | 6.076 ns | 6.475 ns | 30.825 ns | 115.943 ns | Release build with runtime defaults. This is the matrix baseline. |
| `release-native-tuning` | Whole-program | 1.01x | 8.142 ns | 8.546 ns | 6.081 ns | 6.256 ns | 7.491 ns | 30.884 ns | 113.377 ns | Enables -march=native and -mtune=native. |
| `release-thinlto` | Whole-program | 1.32x | 5.414 ns | 5.847 ns | 7.213 ns | 4.128 ns | 4.925 ns | 27.368 ns | 82.901 ns | Enables ThinLTO. |
| `release-full-lto` | Whole-program | 1.64x | 5.362 ns | 6.003 ns | 2.277 ns | 3.030 ns | 5.255 ns | 24.928 ns | 79.158 ns | Enables full LTO. |
| `release-pgo-gen` | Instrumentation | 0.59x | 11.981 ns | 12.082 ns | 7.954 ns | 10.108 ns | 18.849 ns | 60.118 ns | 229.292 ns | Instrumentation-only PGO generation build. |
| `release-pgo-use` | Whole-program | 1.30x | 5.914 ns | 6.305 ns | 3.939 ns | 4.876 ns | 6.296 ns | 29.197 ns | 88.805 ns | Profile-guided optimization on the default release stack. |
| `release-pgo-use-bolt` | Whole-program | 1.05x | 6.031 ns | 14.956 ns | 5.187 ns | 5.641 ns | 7.098 ns | 30.722 ns | 91.251 ns | Default release stack with PGO and BOLT. |
| `release-full-lto-pgo` | Whole-program | 1.88x | 4.663 ns | 5.149 ns | 2.143 ns | 2.870 ns | 4.631 ns | 21.928 ns | 57.850 ns | Measured best whole-program stack without native tuning. |
| `release-full-lto-native-pgo-bolt` | Whole-program | 1.60x | 5.022 ns | 16.191 ns | 2.045 ns | 2.688 ns | 4.783 ns | 21.871 ns | 56.618 ns | Measured fastest release stack on Linux x86_64: full LTO, native tuning, PGO, and BOLT. |
| `release-dispatch-c` | Dispatch / behavior | 0.98x | 6.431 ns | 15.912 ns | 5.258 ns | 6.177 ns | 6.616 ns | 31.300 ns | 116.887 ns | Uses the C message send path instead of the assembly fast path. |
| `release-forwarding` | Dispatch / behavior | 0.97x | 8.526 ns | 8.918 ns | 5.320 ns | 6.384 ns | 8.083 ns | 35.076 ns | 121.012 ns | Enables forwarding and the cold miss path. |
| `release-validation` | Dispatch / behavior | 0.91x | 6.847 ns | 16.460 ns | 5.061 ns | 6.293 ns | 8.940 ns | 35.708 ns | 122.739 ns | Adds defensive object validation checks. |
| `release-tagged-pointers` | Dispatch / behavior | 0.92x | 7.239 ns | 7.444 ns | 7.177 ns | 8.222 ns | 9.508 ns | 34.273 ns | 120.657 ns | Enables tagged pointer support. |
| `release-exceptions-off` | Dispatch / behavior | 1.10x | 6.602 ns | 6.878 ns | 5.086 ns | 5.679 ns | 7.885 ns | 30.900 ns | 112.354 ns | Disables Objective-C exceptions support. |
| `release-reflection-off` | Dispatch / behavior | 0.99x | 6.523 ns | 14.779 ns | 5.424 ns | 6.178 ns | 6.510 ns | 31.750 ns | 116.991 ns | Disables reflection support. |
| `release-compact-headers` | Layout / ABI | 0.87x | 6.892 ns | 17.139 ns | 5.664 ns | 6.582 ns | 8.132 ns | 35.228 ns | 151.905 ns | Uses the compact runtime object header layout. |
| `release-inline-value-storage` | Layout / ABI | 0.91x | 6.869 ns | 11.536 ns | 5.510 ns | 6.521 ns | 7.833 ns | 34.724 ns | 179.569 ns | Enables compact inline ValueObject prefixes and the compact-header prerequisite. |
| `release-inline-group-state` | Layout / ABI | 0.89x | 6.940 ns | 19.733 ns | 5.457 ns | 6.431 ns | 7.629 ns | 34.275 ns | 132.873 ns | Stores parent/group bookkeeping inline and enables the compact-header prerequisite. |
| `release-analysis-symbols` | Instrumentation | 1.00x | 6.448 ns | 15.792 ns | 5.308 ns | 6.136 ns | 6.464 ns | 30.569 ns | 113.486 ns | Keeps debug symbols, disables strip, and emits relocations. |

## Baseline Reference

- `gnustep-2.3 release-default`: `/workspaces/smallfw/build/runtime-analysis/performance-matrix-curated-v3-fixed/runs/release-default-gnustep`
- `objfw-1.5 release-default`: `/workspaces/smallfw/build/runtime-analysis/performance-matrix-curated-v3-fixed/runs/release-default-objfw`
- Matrix JSON: `/workspaces/smallfw/build/runtime-analysis/performance-matrix-curated-v3-fixed/matrix.json`
