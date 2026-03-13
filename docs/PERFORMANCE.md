# Runtime Performance Matrix

This document is generated from measured `xmake run-runtime-bench` runs on the current host.
The full matrix covers every Linux `x86_64` runtime mode/flag row currently exercised by the repo matrix across the selected Objective-C ABIs.
Relative speedups are computed against the matching mode baseline inside the same ABI: `debug-default` for debug rows and `release-default` for release rows.

Generated at: `2026-03-13T13:54:41Z`
Regenerate with: `xmake run-runtime-performance-matrix --matrix=full --samples=5 --warmups=1 --objc-runtimes=both --outdir=build/runtime-analysis/performance-matrix-full --doc=docs/PERFORMANCE.md`

## Environment

- Host: `linux`
- Architecture: `x86_64`
- Objective-C runtimes benchmarked: `gnustep-2.3`, `objfw-1.5`
- `uname -srvm`: `Linux 6.17.7-ba25.fc43.x86_64 #1 SMP PREEMPT_DYNAMIC Mon Jan 19 05:47:43 UTC 2026 x86_64`
- `clang --version`: `Debian clang version 21.1.8 (++20251221033036+2078da43e25a-1~exp1~20251221153213.50)`
- `xmake --version`: `xmake v3.0.7+dev.f9d6d50, A cross-platform build utility based on Lua`
- Samples per variant: `5`
- Warmups per variant: `1`
- Benchmark artifact root: `/workspaces/smallfw/build/runtime-analysis/performance-matrix-full`


## Methodology

- Summary tables report sample means in nanoseconds.
- Geometric means are computed from per-benchmark speedups against the matching ABI+mode baseline.
- Detailed `median`, `min`, `max`, and `stdev` values are preserved in `matrix.json` and each variant `summary.json`.
- `runtime-bench` pins execution to CPU 0 via `taskset` when available.
- Sanitized rows are run with `ASAN_OPTIONS=detect_leaks=0:abort_on_error=1` and `UBSAN_OPTIONS=halt_on_error=1:print_stacktrace=1`.

## Coverage

- Matrix kind: `full`
- Variants attempted: `50`
- Variants completed: `50`
- Variants failed: `0`
- Benchmarks: `dispatch_monomorphic_hot`, `dispatch_polymorphic_hot`, `arc_retain_release_heap`, `arc_retain_release_round_robin`, `arc_store_strong_cycle`, `alloc_init_release_plain`, `parent_group_cycle`

## Variant Definitions

| Variant | ABI | Category | Mode | PGO | BOLT | Changed Options | Status | Failure | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `debug-default` | `gnustep-2.3` | Modes | `debug` | `off` | `off` | `objc-runtime=gnustep-2.3` | ok | - | Debug build with runtime defaults. This is the debug baseline. |
| `debug-default` | `objfw-1.5` | Modes | `debug` | `off` | `off` | `objc-runtime=objfw-1.5` | ok | - | Debug build with runtime defaults. This is the debug baseline. |
| `debug-dispatch-c` | `gnustep-2.3` | Dispatch / behavior | `debug` | `off` | `off` | `objc-runtime=gnustep-2.3`, `dispatch-backend=c` | ok | - | Uses the C message send path instead of the assembly fast path. |
| `debug-dispatch-c` | `objfw-1.5` | Dispatch / behavior | `debug` | `off` | `off` | `objc-runtime=objfw-1.5`, `dispatch-backend=c` | ok | - | Uses the C message send path instead of the assembly fast path. |
| `debug-exceptions-off` | `gnustep-2.3` | Dispatch / behavior | `debug` | `off` | `off` | `objc-runtime=gnustep-2.3`, `runtime-exceptions=n` | ok | - | Disables Objective-C exceptions support. |
| `debug-exceptions-off` | `objfw-1.5` | Dispatch / behavior | `debug` | `off` | `off` | `objc-runtime=objfw-1.5`, `runtime-exceptions=n` | ok | - | Disables Objective-C exceptions support. |
| `debug-reflection-off` | `gnustep-2.3` | Dispatch / behavior | `debug` | `off` | `off` | `objc-runtime=gnustep-2.3`, `runtime-reflection=n` | ok | - | Disables reflection support. |
| `debug-reflection-off` | `objfw-1.5` | Dispatch / behavior | `debug` | `off` | `off` | `objc-runtime=objfw-1.5`, `runtime-reflection=n` | ok | - | Disables reflection support. |
| `debug-forwarding` | `gnustep-2.3` | Dispatch / behavior | `debug` | `off` | `off` | `objc-runtime=gnustep-2.3`, `runtime-forwarding=y` | ok | - | Enables forwarding and the cold miss path. |
| `debug-forwarding` | `objfw-1.5` | Dispatch / behavior | `debug` | `off` | `off` | `objc-runtime=objfw-1.5`, `runtime-forwarding=y` | ok | - | Enables forwarding and the cold miss path. |
| `debug-validation` | `gnustep-2.3` | Dispatch / behavior | `debug` | `off` | `off` | `objc-runtime=gnustep-2.3`, `runtime-validation=y` | ok | - | Adds defensive object validation checks. |
| `debug-validation` | `objfw-1.5` | Dispatch / behavior | `debug` | `off` | `off` | `objc-runtime=objfw-1.5`, `runtime-validation=y` | ok | - | Adds defensive object validation checks. |
| `debug-tagged-pointers` | `gnustep-2.3` | Dispatch / behavior | `debug` | `off` | `off` | `objc-runtime=gnustep-2.3`, `runtime-tagged-pointers=y` | ok | - | Enables tagged pointer support. |
| `debug-tagged-pointers` | `objfw-1.5` | Dispatch / behavior | `debug` | `off` | `off` | `objc-runtime=objfw-1.5`, `runtime-tagged-pointers=y` | ok | - | Enables tagged pointer support. |
| `debug-compact-headers` | `gnustep-2.3` | Layout / ABI | `debug` | `off` | `off` | `objc-runtime=gnustep-2.3`, `runtime-compact-headers=y` | ok | - | Uses the compact runtime object header layout. |
| `debug-compact-headers` | `objfw-1.5` | Layout / ABI | `debug` | `off` | `off` | `objc-runtime=objfw-1.5`, `runtime-compact-headers=y` | ok | - | Uses the compact runtime object header layout. |
| `debug-inline-value-storage` | `gnustep-2.3` | Layout / ABI | `debug` | `off` | `off` | `objc-runtime=gnustep-2.3`, `runtime-compact-headers=y`, `runtime-inline-value-storage=y` | ok | - | Enables compact inline ValueObject prefixes and the compact-header prerequisite. |
| `debug-inline-value-storage` | `objfw-1.5` | Layout / ABI | `debug` | `off` | `off` | `objc-runtime=objfw-1.5`, `runtime-compact-headers=y`, `runtime-inline-value-storage=y` | ok | - | Enables compact inline ValueObject prefixes and the compact-header prerequisite. |
| `debug-inline-group-state` | `gnustep-2.3` | Layout / ABI | `debug` | `off` | `off` | `objc-runtime=gnustep-2.3`, `runtime-compact-headers=y`, `runtime-inline-group-state=y` | ok | - | Stores parent/group bookkeeping inline and enables the compact-header prerequisite. |
| `debug-inline-group-state` | `objfw-1.5` | Layout / ABI | `debug` | `off` | `off` | `objc-runtime=objfw-1.5`, `runtime-compact-headers=y`, `runtime-inline-group-state=y` | ok | - | Stores parent/group bookkeeping inline and enables the compact-header prerequisite. |
| `debug-sanitize` | `gnustep-2.3` | Instrumentation | `debug` | `off` | `off` | `objc-runtime=gnustep-2.3`, `runtime-sanitize=y` | ok | - | Enables ASan and UBSan for analysis builds. |
| `debug-sanitize` | `objfw-1.5` | Instrumentation | `debug` | `off` | `off` | `objc-runtime=objfw-1.5`, `runtime-sanitize=y` | ok | - | Enables ASan and UBSan for analysis builds. |
| `release-default` | `gnustep-2.3` | Modes | `release` | `off` | `off` | `objc-runtime=gnustep-2.3` | ok | - | Release build with runtime defaults. This is the release baseline. |
| `release-default` | `objfw-1.5` | Modes | `release` | `off` | `off` | `objc-runtime=objfw-1.5` | ok | - | Release build with runtime defaults. This is the release baseline. |
| `release-dispatch-c` | `gnustep-2.3` | Dispatch / behavior | `release` | `off` | `off` | `objc-runtime=gnustep-2.3`, `dispatch-backend=c` | ok | - | Uses the C message send path instead of the assembly fast path. |
| `release-dispatch-c` | `objfw-1.5` | Dispatch / behavior | `release` | `off` | `off` | `objc-runtime=objfw-1.5`, `dispatch-backend=c` | ok | - | Uses the C message send path instead of the assembly fast path. |
| `release-exceptions-off` | `gnustep-2.3` | Dispatch / behavior | `release` | `off` | `off` | `objc-runtime=gnustep-2.3`, `runtime-exceptions=n` | ok | - | Disables Objective-C exceptions support. |
| `release-exceptions-off` | `objfw-1.5` | Dispatch / behavior | `release` | `off` | `off` | `objc-runtime=objfw-1.5`, `runtime-exceptions=n` | ok | - | Disables Objective-C exceptions support. |
| `release-reflection-off` | `gnustep-2.3` | Dispatch / behavior | `release` | `off` | `off` | `objc-runtime=gnustep-2.3`, `runtime-reflection=n` | ok | - | Disables reflection support. |
| `release-reflection-off` | `objfw-1.5` | Dispatch / behavior | `release` | `off` | `off` | `objc-runtime=objfw-1.5`, `runtime-reflection=n` | ok | - | Disables reflection support. |
| `release-forwarding` | `gnustep-2.3` | Dispatch / behavior | `release` | `off` | `off` | `objc-runtime=gnustep-2.3`, `runtime-forwarding=y` | ok | - | Enables forwarding and the cold miss path. |
| `release-forwarding` | `objfw-1.5` | Dispatch / behavior | `release` | `off` | `off` | `objc-runtime=objfw-1.5`, `runtime-forwarding=y` | ok | - | Enables forwarding and the cold miss path. |
| `release-validation` | `gnustep-2.3` | Dispatch / behavior | `release` | `off` | `off` | `objc-runtime=gnustep-2.3`, `runtime-validation=y` | ok | - | Adds defensive object validation checks. |
| `release-validation` | `objfw-1.5` | Dispatch / behavior | `release` | `off` | `off` | `objc-runtime=objfw-1.5`, `runtime-validation=y` | ok | - | Adds defensive object validation checks. |
| `release-tagged-pointers` | `gnustep-2.3` | Dispatch / behavior | `release` | `off` | `off` | `objc-runtime=gnustep-2.3`, `runtime-tagged-pointers=y` | ok | - | Enables tagged pointer support. |
| `release-tagged-pointers` | `objfw-1.5` | Dispatch / behavior | `release` | `off` | `off` | `objc-runtime=objfw-1.5`, `runtime-tagged-pointers=y` | ok | - | Enables tagged pointer support. |
| `release-compact-headers` | `gnustep-2.3` | Layout / ABI | `release` | `off` | `off` | `objc-runtime=gnustep-2.3`, `runtime-compact-headers=y` | ok | - | Uses the compact runtime object header layout. |
| `release-compact-headers` | `objfw-1.5` | Layout / ABI | `release` | `off` | `off` | `objc-runtime=objfw-1.5`, `runtime-compact-headers=y` | ok | - | Uses the compact runtime object header layout. |
| `release-inline-value-storage` | `gnustep-2.3` | Layout / ABI | `release` | `off` | `off` | `objc-runtime=gnustep-2.3`, `runtime-compact-headers=y`, `runtime-inline-value-storage=y` | ok | - | Enables compact inline ValueObject prefixes and the compact-header prerequisite. |
| `release-inline-value-storage` | `objfw-1.5` | Layout / ABI | `release` | `off` | `off` | `objc-runtime=objfw-1.5`, `runtime-compact-headers=y`, `runtime-inline-value-storage=y` | ok | - | Enables compact inline ValueObject prefixes and the compact-header prerequisite. |
| `release-inline-group-state` | `gnustep-2.3` | Layout / ABI | `release` | `off` | `off` | `objc-runtime=gnustep-2.3`, `runtime-compact-headers=y`, `runtime-inline-group-state=y` | ok | - | Stores parent/group bookkeeping inline and enables the compact-header prerequisite. |
| `release-inline-group-state` | `objfw-1.5` | Layout / ABI | `release` | `off` | `off` | `objc-runtime=objfw-1.5`, `runtime-compact-headers=y`, `runtime-inline-group-state=y` | ok | - | Stores parent/group bookkeeping inline and enables the compact-header prerequisite. |
| `release-analysis-symbols` | `gnustep-2.3` | Instrumentation | `release` | `off` | `off` | `analysis-symbols=y`, `objc-runtime=gnustep-2.3` | ok | - | Keeps debug symbols, disables strip, and emits relocations. |
| `release-analysis-symbols` | `objfw-1.5` | Instrumentation | `release` | `off` | `off` | `analysis-symbols=y`, `objc-runtime=objfw-1.5` | ok | - | Keeps debug symbols, disables strip, and emits relocations. |
| `release-native-tuning` | `gnustep-2.3` | Whole-program | `release` | `off` | `off` | `objc-runtime=gnustep-2.3`, `runtime-native-tuning=y` | ok | - | Enables -march=native and -mtune=native. |
| `release-native-tuning` | `objfw-1.5` | Whole-program | `release` | `off` | `off` | `objc-runtime=objfw-1.5`, `runtime-native-tuning=y` | ok | - | Enables -march=native and -mtune=native. |
| `release-thinlto` | `gnustep-2.3` | Whole-program | `release` | `off` | `off` | `objc-runtime=gnustep-2.3`, `runtime-thinlto=y` | ok | - | Enables ThinLTO. |
| `release-thinlto` | `objfw-1.5` | Whole-program | `release` | `off` | `off` | `objc-runtime=objfw-1.5`, `runtime-thinlto=y` | ok | - | Enables ThinLTO. |
| `release-full-lto` | `gnustep-2.3` | Whole-program | `release` | `off` | `off` | `objc-runtime=gnustep-2.3`, `runtime-full-lto=y` | ok | - | Enables full LTO. |
| `release-full-lto` | `objfw-1.5` | Whole-program | `release` | `off` | `off` | `objc-runtime=objfw-1.5`, `runtime-full-lto=y` | ok | - | Enables full LTO. |

## Leaderboard

### GNUstep ABI Release

| Rank | Variant | Category | Geo Mean vs ABI `release-default` | Best Case | Worst Case | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | `release-full-lto` | Whole-program | 1.63x | `arc_retain_release_round_robin` (2.45x) | `dispatch_monomorphic_hot` (1.00x) | Enables full LTO. |
| 2 | `release-thinlto` | Whole-program | 1.44x | `arc_store_strong_cycle` (2.36x) | `dispatch_polymorphic_hot` (1.00x) | Enables ThinLTO. |
| 3 | `release-exceptions-off` | Dispatch / behavior | 1.02x | `alloc_init_release_plain` (1.08x) | `arc_retain_release_heap` (0.99x) | Disables Objective-C exceptions support. |
| 4 | `release-native-tuning` | Whole-program | 1.01x | `dispatch_polymorphic_hot` (1.07x) | `arc_retain_release_heap` (0.95x) | Enables -march=native and -mtune=native. |
| 5 | `release-default` | Modes | 1.00x | `dispatch_monomorphic_hot` (1.00x) | `dispatch_monomorphic_hot` (1.00x) | Release build with runtime defaults. This is the release baseline. |
| 6 | `release-analysis-symbols` | Instrumentation | 0.99x | `arc_retain_release_round_robin` (1.00x) | `arc_retain_release_heap` (0.98x) | Keeps debug symbols, disables strip, and emits relocations. |
| 7 | `release-reflection-off` | Dispatch / behavior | 0.98x | `dispatch_monomorphic_hot` (0.99x) | `arc_store_strong_cycle` (0.97x) | Disables reflection support. |
| 8 | `release-forwarding` | Dispatch / behavior | 0.97x | `arc_store_strong_cycle` (0.99x) | `parent_group_cycle` (0.92x) | Enables forwarding and the cold miss path. |
| 9 | `release-compact-headers` | Layout / ABI | 0.93x | `arc_store_strong_cycle` (1.01x) | `parent_group_cycle` (0.69x) | Uses the compact runtime object header layout. |
| 10 | `release-inline-group-state` | Layout / ABI | 0.92x | `dispatch_polymorphic_hot` (1.01x) | `parent_group_cycle` (0.79x) | Stores parent/group bookkeeping inline and enables the compact-header prerequisite. |
| 11 | `release-validation` | Dispatch / behavior | 0.89x | `dispatch_monomorphic_hot` (0.99x) | `arc_store_strong_cycle` (0.81x) | Adds defensive object validation checks. |
| 12 | `release-inline-value-storage` | Layout / ABI | 0.88x | `dispatch_polymorphic_hot` (1.01x) | `parent_group_cycle` (0.54x) | Enables compact inline ValueObject prefixes and the compact-header prerequisite. |
| 13 | `release-tagged-pointers` | Dispatch / behavior | 0.85x | `arc_retain_release_round_robin` (0.98x) | `alloc_init_release_plain` (0.62x) | Enables tagged pointer support. |
| 14 | `release-dispatch-c` | Dispatch / behavior | 0.27x | `arc_retain_release_round_robin` (1.06x) | `dispatch_monomorphic_hot` (0.03x) | Uses the C message send path instead of the assembly fast path. |

### GNUstep ABI Debug

| Rank | Variant | Category | Geo Mean vs ABI `debug-default` | Best Case | Worst Case | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | `debug-reflection-off` | Dispatch / behavior | 1.03x | `parent_group_cycle` (1.10x) | `dispatch_polymorphic_hot` (1.00x) | Disables reflection support. |
| 2 | `debug-exceptions-off` | Dispatch / behavior | 1.02x | `parent_group_cycle` (1.05x) | `dispatch_polymorphic_hot` (0.94x) | Disables Objective-C exceptions support. |
| 3 | `debug-forwarding` | Dispatch / behavior | 1.02x | `arc_retain_release_heap` (1.08x) | `dispatch_polymorphic_hot` (0.97x) | Enables forwarding and the cold miss path. |
| 4 | `debug-default` | Modes | 1.00x | `dispatch_monomorphic_hot` (1.00x) | `dispatch_monomorphic_hot` (1.00x) | Debug build with runtime defaults. This is the debug baseline. |
| 5 | `debug-validation` | Dispatch / behavior | 0.99x | `arc_store_strong_cycle` (1.12x) | `alloc_init_release_plain` (0.84x) | Adds defensive object validation checks. |
| 6 | `debug-tagged-pointers` | Dispatch / behavior | 0.95x | `arc_retain_release_heap` (1.09x) | `arc_store_strong_cycle` (0.82x) | Enables tagged pointer support. |
| 7 | `debug-inline-group-state` | Layout / ABI | 0.88x | `arc_store_strong_cycle` (1.04x) | `parent_group_cycle` (0.61x) | Stores parent/group bookkeeping inline and enables the compact-header prerequisite. |
| 8 | `debug-compact-headers` | Layout / ABI | 0.86x | `arc_retain_release_heap` (1.08x) | `parent_group_cycle` (0.52x) | Uses the compact runtime object header layout. |
| 9 | `debug-inline-value-storage` | Layout / ABI | 0.79x | `arc_retain_release_heap` (1.07x) | `parent_group_cycle` (0.42x) | Enables compact inline ValueObject prefixes and the compact-header prerequisite. |
| 10 | `debug-sanitize` | Instrumentation | 0.31x | `dispatch_monomorphic_hot` (0.64x) | `arc_store_strong_cycle` (0.13x) | Enables ASan and UBSan for analysis builds. |
| 11 | `debug-dispatch-c` | Dispatch / behavior | 0.22x | `arc_store_strong_cycle` (1.10x) | `dispatch_polymorphic_hot` (0.01x) | Uses the C message send path instead of the assembly fast path. |

### ObjFW ABI Release

| Rank | Variant | Category | Geo Mean vs ABI `release-default` | Best Case | Worst Case | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | `release-full-lto` | Whole-program | 1.88x | `arc_retain_release_round_robin` (2.54x) | `dispatch_monomorphic_hot` (1.16x) | Enables full LTO. |
| 2 | `release-thinlto` | Whole-program | 1.59x | `arc_store_strong_cycle` (2.93x) | `arc_retain_release_heap` (1.07x) | Enables ThinLTO. |
| 3 | `release-exceptions-off` | Dispatch / behavior | 1.02x | `arc_store_strong_cycle` (1.14x) | `dispatch_monomorphic_hot` (0.83x) | Disables Objective-C exceptions support. |
| 4 | `release-analysis-symbols` | Instrumentation | 1.02x | `arc_store_strong_cycle` (1.09x) | `parent_group_cycle` (0.99x) | Keeps debug symbols, disables strip, and emits relocations. |
| 5 | `release-tagged-pointers` | Dispatch / behavior | 1.02x | `dispatch_polymorphic_hot` (1.65x) | `arc_retain_release_round_robin` (0.83x) | Enables tagged pointer support. |
| 6 | `release-native-tuning` | Whole-program | 1.01x | `arc_store_strong_cycle` (1.27x) | `dispatch_monomorphic_hot` (0.70x) | Enables -march=native and -mtune=native. |
| 7 | `release-default` | Modes | 1.00x | `dispatch_monomorphic_hot` (1.00x) | `dispatch_monomorphic_hot` (1.00x) | Release build with runtime defaults. This is the release baseline. |
| 8 | `release-dispatch-c` | Dispatch / behavior | 0.98x | `arc_store_strong_cycle` (1.06x) | `dispatch_monomorphic_hot` (0.93x) | Uses the C message send path instead of the assembly fast path. |
| 9 | `release-inline-group-state` | Layout / ABI | 0.98x | `arc_retain_release_heap` (1.05x) | `parent_group_cycle` (0.85x) | Stores parent/group bookkeeping inline and enables the compact-header prerequisite. |
| 10 | `release-forwarding` | Dispatch / behavior | 0.96x | `dispatch_polymorphic_hot` (1.28x) | `dispatch_monomorphic_hot` (0.62x) | Enables forwarding and the cold miss path. |
| 11 | `release-compact-headers` | Layout / ABI | 0.96x | `arc_store_strong_cycle` (1.17x) | `parent_group_cycle` (0.66x) | Uses the compact runtime object header layout. |
| 12 | `release-validation` | Dispatch / behavior | 0.95x | `arc_store_strong_cycle` (1.11x) | `alloc_init_release_plain` (0.81x) | Adds defensive object validation checks. |
| 13 | `release-reflection-off` | Dispatch / behavior | 0.94x | `arc_store_strong_cycle` (1.09x) | `arc_retain_release_round_robin` (0.80x) | Disables reflection support. |
| 14 | `release-inline-value-storage` | Layout / ABI | 0.92x | `arc_retain_release_heap` (1.04x) | `parent_group_cycle` (0.61x) | Enables compact inline ValueObject prefixes and the compact-header prerequisite. |

### ObjFW ABI Debug

| Rank | Variant | Category | Geo Mean vs ABI `debug-default` | Best Case | Worst Case | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | `debug-reflection-off` | Dispatch / behavior | 1.02x | `arc_retain_release_round_robin` (1.05x) | `arc_retain_release_heap` (1.00x) | Disables reflection support. |
| 2 | `debug-exceptions-off` | Dispatch / behavior | 1.00x | `alloc_init_release_plain` (1.07x) | `parent_group_cycle` (0.93x) | Disables Objective-C exceptions support. |
| 3 | `debug-default` | Modes | 1.00x | `dispatch_monomorphic_hot` (1.00x) | `dispatch_monomorphic_hot` (1.00x) | Debug build with runtime defaults. This is the debug baseline. |
| 4 | `debug-dispatch-c` | Dispatch / behavior | 0.99x | `alloc_init_release_plain` (1.02x) | `arc_retain_release_heap` (0.95x) | Uses the C message send path instead of the assembly fast path. |
| 5 | `debug-validation` | Dispatch / behavior | 0.97x | `arc_retain_release_round_robin` (1.09x) | `arc_store_strong_cycle` (0.92x) | Adds defensive object validation checks. |
| 6 | `debug-forwarding` | Dispatch / behavior | 0.95x | `arc_store_strong_cycle` (1.05x) | `parent_group_cycle` (0.84x) | Enables forwarding and the cold miss path. |
| 7 | `debug-tagged-pointers` | Dispatch / behavior | 0.94x | `alloc_init_release_plain` (1.03x) | `arc_store_strong_cycle` (0.75x) | Enables tagged pointer support. |
| 8 | `debug-inline-group-state` | Layout / ABI | 0.90x | `arc_retain_release_round_robin` (1.02x) | `parent_group_cycle` (0.64x) | Stores parent/group bookkeeping inline and enables the compact-header prerequisite. |
| 9 | `debug-compact-headers` | Layout / ABI | 0.88x | `arc_retain_release_round_robin` (1.02x) | `parent_group_cycle` (0.53x) | Uses the compact runtime object header layout. |
| 10 | `debug-inline-value-storage` | Layout / ABI | 0.84x | `dispatch_polymorphic_hot` (1.01x) | `parent_group_cycle` (0.48x) | Enables compact inline ValueObject prefixes and the compact-header prerequisite. |
| 11 | `debug-sanitize` | Instrumentation | 0.30x | `arc_retain_release_heap` (0.49x) | `arc_store_strong_cycle` (0.12x) | Enables ASan and UBSan for analysis builds. |

## ObjFW vs GNUstep

### Release

| Variant | ObjFW vs GNUstep | Winner | Best ObjFW Case | Worst ObjFW Case | Notes |
| --- | --- | --- | --- | --- | --- |
| `release-dispatch-c` | 1.49x | ObjFW ABI | `dispatch_monomorphic_hot` (3.35x) | `arc_store_strong_cycle` (0.86x) | Uses the C message send path instead of the assembly fast path. |
| `release-tagged-pointers` | 0.49x | GNUstep ABI | `arc_retain_release_heap` (0.98x) | `dispatch_polymorphic_hot` (0.10x) | Enables tagged pointer support. |
| `release-full-lto` | 0.47x | GNUstep ABI | `arc_store_strong_cycle` (1.33x) | `dispatch_monomorphic_hot` (0.11x) | Enables full LTO. |
| `release-thinlto` | 0.45x | GNUstep ABI | `arc_store_strong_cycle` (1.03x) | `dispatch_polymorphic_hot` (0.10x) | Enables ThinLTO. |
| `release-validation` | 0.44x | GNUstep ABI | `arc_store_strong_cycle` (1.13x) | `dispatch_polymorphic_hot` (0.06x) | Adds defensive object validation checks. |
| `release-inline-group-state` | 0.43x | GNUstep ABI | `arc_retain_release_round_robin` (1.22x) | `dispatch_polymorphic_hot` (0.06x) | Stores parent/group bookkeeping inline and enables the compact-header prerequisite. |
| `release-inline-value-storage` | 0.42x | GNUstep ABI | `arc_retain_release_heap` (1.08x) | `dispatch_polymorphic_hot` (0.06x) | Enables compact inline ValueObject prefixes and the compact-header prerequisite. |
| `release-compact-headers` | 0.42x | GNUstep ABI | `arc_retain_release_heap` (1.10x) | `dispatch_polymorphic_hot` (0.06x) | Uses the compact runtime object header layout. |
| `release-analysis-symbols` | 0.42x | GNUstep ABI | `arc_retain_release_heap` (0.97x) | `dispatch_polymorphic_hot` (0.06x) | Keeps debug symbols, disables strip, and emits relocations. |
| `release-native-tuning` | 0.41x | GNUstep ABI | `arc_store_strong_cycle` (1.04x) | `dispatch_monomorphic_hot` (0.07x) | Enables -march=native and -mtune=native. |
| `release-exceptions-off` | 0.41x | GNUstep ABI | `arc_retain_release_round_robin` (1.03x) | `dispatch_polymorphic_hot` (0.06x) | Disables Objective-C exceptions support. |
| `release-default` | 0.41x | GNUstep ABI | `arc_retain_release_heap` (0.95x) | `dispatch_polymorphic_hot` (0.06x) | Release build with runtime defaults. This is the release baseline. |
| `release-forwarding` | 0.40x | GNUstep ABI | `arc_retain_release_heap` (0.98x) | `dispatch_monomorphic_hot` (0.06x) | Enables forwarding and the cold miss path. |
| `release-reflection-off` | 0.39x | GNUstep ABI | `arc_store_strong_cycle` (0.94x) | `dispatch_polymorphic_hot` (0.05x) | Disables reflection support. |

### Debug

| Variant | ObjFW vs GNUstep | Winner | Best ObjFW Case | Worst ObjFW Case | Notes |
| --- | --- | --- | --- | --- | --- |
| `debug-dispatch-c` | 1.67x | ObjFW ABI | `dispatch_polymorphic_hot` (3.48x) | `arc_retain_release_heap` (0.96x) | Uses the C message send path instead of the assembly fast path. |
| `debug-inline-value-storage` | 0.39x | GNUstep ABI | `arc_retain_release_round_robin` (1.10x) | `dispatch_monomorphic_hot` (0.05x) | Enables compact inline ValueObject prefixes and the compact-header prerequisite. |
| `debug-compact-headers` | 0.38x | GNUstep ABI | `arc_retain_release_round_robin` (1.04x) | `dispatch_monomorphic_hot` (0.05x) | Uses the compact runtime object header layout. |
| `debug-inline-group-state` | 0.38x | GNUstep ABI | `arc_retain_release_round_robin` (1.06x) | `dispatch_monomorphic_hot` (0.04x) | Stores parent/group bookkeeping inline and enables the compact-header prerequisite. |
| `debug-default` | 0.37x | GNUstep ABI | `arc_retain_release_heap` (1.08x) | `dispatch_monomorphic_hot` (0.05x) | Debug build with runtime defaults. This is the debug baseline. |
| `debug-reflection-off` | 0.37x | GNUstep ABI | `arc_store_strong_cycle` (1.07x) | `dispatch_monomorphic_hot` (0.05x) | Disables reflection support. |
| `debug-tagged-pointers` | 0.37x | GNUstep ABI | `arc_retain_release_heap` (0.99x) | `dispatch_monomorphic_hot` (0.04x) | Enables tagged pointer support. |
| `debug-exceptions-off` | 0.36x | GNUstep ABI | `arc_retain_release_round_robin` (1.06x) | `dispatch_monomorphic_hot` (0.04x) | Disables Objective-C exceptions support. |
| `debug-validation` | 0.36x | GNUstep ABI | `arc_retain_release_heap` (1.04x) | `dispatch_monomorphic_hot` (0.05x) | Adds defensive object validation checks. |
| `debug-sanitize` | 0.36x | GNUstep ABI | `arc_retain_release_round_robin` (1.03x) | `dispatch_monomorphic_hot` (0.03x) | Enables ASan and UBSan for analysis builds. |
| `debug-forwarding` | 0.35x | GNUstep ABI | `arc_store_strong_cycle` (1.12x) | `dispatch_monomorphic_hot` (0.04x) | Enables forwarding and the cold miss path. |

## Fastest Variant Per Benchmark

| Benchmark | Fastest Variant | Mode | ABI | Mean | Speedup vs matching baseline |
| --- | --- | --- | --- | --- | --- |
| `dispatch_monomorphic_hot` | `release-inline-group-state` | `release` | GNUstep ABI | 0.577 ns | 1.01x |
| `dispatch_polymorphic_hot` | `release-native-tuning` | `release` | GNUstep ABI | 0.632 ns | 1.07x |
| `arc_retain_release_heap` | `release-full-lto` | `release` | GNUstep ABI | 3.040 ns | 2.26x |
| `arc_retain_release_round_robin` | `release-full-lto` | `release` | GNUstep ABI | 3.869 ns | 2.45x |
| `arc_store_strong_cycle` | `release-thinlto` | `release` | ObjFW ABI | 5.966 ns | 2.93x |
| `alloc_init_release_plain` | `release-full-lto` | `release` | GNUstep ABI | 13.075 ns | 1.85x |
| `parent_group_cycle` | `release-full-lto` | `release` | GNUstep ABI | 41.540 ns | 1.91x |

## ASM vs C Backend

| ABI | Mode | Benchmark | ASM Mean | C Mean | ASM Advantage |
| --- | --- | --- | --- | --- | --- |
| GNUstep ABI | `release` | `dispatch_monomorphic_hot` | 0.580 ns | 22.194 ns | 38.27x |
| GNUstep ABI | `release` | `dispatch_polymorphic_hot` | 0.679 ns | 22.369 ns | 32.93x |
| GNUstep ABI | `release` | `arc_retain_release_heap` | 6.883 ns | 7.063 ns | 1.03x |
| GNUstep ABI | `release` | `arc_retain_release_round_robin` | 9.470 ns | 8.975 ns | 0.95x |
| GNUstep ABI | `release` | `arc_store_strong_cycle` | 14.493 ns | 14.183 ns | 0.98x |
| GNUstep ABI | `release` | `alloc_init_release_plain` | 24.201 ns | 86.223 ns | 3.56x |
| GNUstep ABI | `release` | `parent_group_cycle` | 79.357 ns | 182.524 ns | 2.30x |
| ObjFW ABI | `release` | `dispatch_monomorphic_hot` | 6.141 ns | 6.619 ns | 1.08x |
| ObjFW ABI | `release` | `dispatch_polymorphic_hot` | 11.179 ns | 10.679 ns | 0.96x |
| ObjFW ABI | `release` | `arc_retain_release_heap` | 7.235 ns | 7.367 ns | 1.02x |
| ObjFW ABI | `release` | `arc_retain_release_round_robin` | 9.957 ns | 10.403 ns | 1.04x |
| ObjFW ABI | `release` | `arc_store_strong_cycle` | 17.453 ns | 16.522 ns | 0.95x |
| ObjFW ABI | `release` | `alloc_init_release_plain` | 40.366 ns | 41.211 ns | 1.02x |
| ObjFW ABI | `release` | `parent_group_cycle` | 111.122 ns | 116.754 ns | 1.05x |
| GNUstep ABI | `debug` | `dispatch_monomorphic_hot` | 1.121 ns | 81.346 ns | 72.58x |
| GNUstep ABI | `debug` | `dispatch_polymorphic_hot` | 1.155 ns | 84.051 ns | 72.77x |
| GNUstep ABI | `debug` | `arc_retain_release_heap` | 21.707 ns | 20.226 ns | 0.93x |
| GNUstep ABI | `debug` | `arc_retain_release_round_robin` | 37.424 ns | 36.383 ns | 0.97x |
| GNUstep ABI | `debug` | `arc_store_strong_cycle` | 43.638 ns | 39.843 ns | 0.91x |
| GNUstep ABI | `debug` | `alloc_init_release_plain` | 71.408 ns | 293.921 ns | 4.12x |
| GNUstep ABI | `debug` | `parent_group_cycle` | 312.899 ns | 693.845 ns | 2.22x |
| ObjFW ABI | `debug` | `dispatch_monomorphic_hot` | 24.077 ns | 24.063 ns | 1.00x |
| ObjFW ABI | `debug` | `dispatch_polymorphic_hot` | 24.196 ns | 24.180 ns | 1.00x |
| ObjFW ABI | `debug` | `arc_retain_release_heap` | 20.007 ns | 21.148 ns | 1.06x |
| ObjFW ABI | `debug` | `arc_retain_release_round_robin` | 36.936 ns | 36.558 ns | 0.99x |
| ObjFW ABI | `debug` | `arc_store_strong_cycle` | 41.735 ns | 41.414 ns | 0.99x |
| ObjFW ABI | `debug` | `alloc_init_release_plain` | 144.634 ns | 141.888 ns | 0.98x |
| ObjFW ABI | `debug` | `parent_group_cycle` | 413.465 ns | 424.718 ns | 1.03x |

## Detailed Matrix

### GNUstep ABI Release

| Variant | Category | Geo Mean vs `release-default` | dispatch_monomorphic_hot | dispatch_polymorphic_hot | arc_retain_release_heap | arc_retain_release_round_robin | arc_store_strong_cycle | alloc_init_release_plain | parent_group_cycle | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `release-default` | Modes | 1.00x | 0.580 ns | 0.679 ns | 6.883 ns | 9.470 ns | 14.493 ns | 24.201 ns | 79.357 ns | Release build with runtime defaults. This is the release baseline. |
| `release-dispatch-c` | Dispatch / behavior | 0.27x | 22.194 ns | 22.369 ns | 7.063 ns | 8.975 ns | 14.183 ns | 86.223 ns | 182.524 ns | Uses the C message send path instead of the assembly fast path. |
| `release-exceptions-off` | Dispatch / behavior | 1.02x | 0.580 ns | 0.677 ns | 6.939 ns | 9.219 ns | 14.069 ns | 22.428 ns | 77.185 ns | Disables Objective-C exceptions support. |
| `release-reflection-off` | Dispatch / behavior | 0.98x | 0.584 ns | 0.693 ns | 7.054 ns | 9.594 ns | 14.958 ns | 24.571 ns | 80.305 ns | Disables reflection support. |
| `release-forwarding` | Dispatch / behavior | 0.97x | 0.593 ns | 0.693 ns | 7.187 ns | 9.602 ns | 14.605 ns | 24.473 ns | 86.355 ns | Enables forwarding and the cold miss path. |
| `release-validation` | Dispatch / behavior | 0.89x | 0.587 ns | 0.691 ns | 7.941 ns | 11.070 ns | 17.812 ns | 28.566 ns | 92.082 ns | Adds defensive object validation checks. |
| `release-tagged-pointers` | Dispatch / behavior | 0.85x | 0.675 ns | 0.696 ns | 7.162 ns | 9.628 ns | 16.674 ns | 39.297 ns | 105.063 ns | Enables tagged pointer support. |
| `release-compact-headers` | Layout / ABI | 0.93x | 0.590 ns | 0.688 ns | 7.567 ns | 9.503 ns | 14.321 ns | 25.364 ns | 114.728 ns | Uses the compact runtime object header layout. |
| `release-inline-value-storage` | Layout / ABI | 0.88x | 0.590 ns | 0.676 ns | 7.483 ns | 9.812 ns | 14.873 ns | 26.644 ns | 145.767 ns | Enables compact inline ValueObject prefixes and the compact-header prerequisite. |
| `release-inline-group-state` | Layout / ABI | 0.92x | 0.577 ns | 0.671 ns | 7.544 ns | 11.972 ns | 14.335 ns | 24.571 ns | 100.540 ns | Stores parent/group bookkeeping inline and enables the compact-header prerequisite. |
| `release-analysis-symbols` | Instrumentation | 0.99x | 0.587 ns | 0.682 ns | 7.001 ns | 9.466 ns | 14.499 ns | 24.530 ns | 80.198 ns | Keeps debug symbols, disables strip, and emits relocations. |
| `release-native-tuning` | Whole-program | 1.01x | 0.583 ns | 0.632 ns | 7.257 ns | 9.195 ns | 14.393 ns | 24.323 ns | 78.977 ns | Enables -march=native and -mtune=native. |
| `release-thinlto` | Whole-program | 1.44x | 0.579 ns | 0.679 ns | 6.210 ns | 5.811 ns | 6.130 ns | 13.101 ns | 48.017 ns | Enables ThinLTO. |
| `release-full-lto` | Whole-program | 1.63x | 0.580 ns | 0.679 ns | 3.040 ns | 3.869 ns | 9.244 ns | 13.075 ns | 41.540 ns | Enables full LTO. |

### GNUstep ABI Debug

| Variant | Category | Geo Mean vs `debug-default` | dispatch_monomorphic_hot | dispatch_polymorphic_hot | arc_retain_release_heap | arc_retain_release_round_robin | arc_store_strong_cycle | alloc_init_release_plain | parent_group_cycle | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `debug-default` | Modes | 1.00x | 1.121 ns | 1.155 ns | 21.707 ns | 37.424 ns | 43.638 ns | 71.408 ns | 312.899 ns | Debug build with runtime defaults. This is the debug baseline. |
| `debug-dispatch-c` | Dispatch / behavior | 0.22x | 81.346 ns | 84.051 ns | 20.226 ns | 36.383 ns | 39.843 ns | 293.921 ns | 693.845 ns | Uses the C message send path instead of the assembly fast path. |
| `debug-exceptions-off` | Dispatch / behavior | 1.02x | 1.108 ns | 1.232 ns | 20.919 ns | 37.264 ns | 41.407 ns | 68.186 ns | 296.872 ns | Disables Objective-C exceptions support. |
| `debug-reflection-off` | Dispatch / behavior | 1.03x | 1.110 ns | 1.159 ns | 20.413 ns | 37.125 ns | 43.447 ns | 70.865 ns | 285.274 ns | Disables reflection support. |
| `debug-forwarding` | Dispatch / behavior | 1.02x | 1.122 ns | 1.192 ns | 20.027 ns | 38.306 ns | 44.262 ns | 70.022 ns | 289.677 ns | Enables forwarding and the cold miss path. |
| `debug-validation` | Dispatch / behavior | 0.99x | 1.132 ns | 1.201 ns | 22.289 ns | 35.053 ns | 38.891 ns | 84.782 ns | 313.425 ns | Adds defensive object validation checks. |
| `debug-tagged-pointers` | Dispatch / behavior | 0.95x | 1.077 ns | 1.191 ns | 19.867 ns | 38.991 ns | 53.032 ns | 74.270 ns | 376.012 ns | Enables tagged pointer support. |
| `debug-compact-headers` | Layout / ABI | 0.86x | 1.108 ns | 1.156 ns | 20.033 ns | 37.537 ns | 43.323 ns | 121.241 ns | 605.176 ns | Uses the compact runtime object header layout. |
| `debug-inline-value-storage` | Layout / ABI | 0.79x | 1.122 ns | 1.174 ns | 20.210 ns | 42.217 ns | 48.400 ns | 129.314 ns | 750.139 ns | Enables compact inline ValueObject prefixes and the compact-header prerequisite. |
| `debug-inline-group-state` | Layout / ABI | 0.88x | 1.105 ns | 1.169 ns | 20.969 ns | 38.223 ns | 42.028 ns | 111.628 ns | 513.217 ns | Stores parent/group bookkeeping inline and enables the compact-header prerequisite. |
| `debug-sanitize` | Instrumentation | 0.31x | 1.764 ns | 2.159 ns | 40.558 ns | 155.346 ns | 346.890 ns | 383.129 ns | 1297.421 ns | Enables ASan and UBSan for analysis builds. |

### ObjFW ABI Release

| Variant | Category | Geo Mean vs `release-default` | dispatch_monomorphic_hot | dispatch_polymorphic_hot | arc_retain_release_heap | arc_retain_release_round_robin | arc_store_strong_cycle | alloc_init_release_plain | parent_group_cycle | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `release-default` | Modes | 1.00x | 6.141 ns | 11.179 ns | 7.235 ns | 9.957 ns | 17.453 ns | 40.366 ns | 111.122 ns | Release build with runtime defaults. This is the release baseline. |
| `release-dispatch-c` | Dispatch / behavior | 0.98x | 6.619 ns | 10.679 ns | 7.367 ns | 10.403 ns | 16.522 ns | 41.211 ns | 116.754 ns | Uses the C message send path instead of the assembly fast path. |
| `release-exceptions-off` | Dispatch / behavior | 1.02x | 7.415 ns | 10.736 ns | 7.027 ns | 8.979 ns | 15.323 ns | 40.009 ns | 107.037 ns | Disables Objective-C exceptions support. |
| `release-reflection-off` | Dispatch / behavior | 0.94x | 6.275 ns | 12.893 ns | 7.915 ns | 12.420 ns | 15.991 ns | 40.870 ns | 112.885 ns | Disables reflection support. |
| `release-forwarding` | Dispatch / behavior | 0.96x | 9.945 ns | 8.710 ns | 7.321 ns | 10.116 ns | 15.265 ns | 43.726 ns | 119.753 ns | Enables forwarding and the cold miss path. |
| `release-validation` | Dispatch / behavior | 0.95x | 6.865 ns | 11.098 ns | 7.421 ns | 9.801 ns | 15.727 ns | 49.819 ns | 128.811 ns | Adds defensive object validation checks. |
| `release-tagged-pointers` | Dispatch / behavior | 1.02x | 6.455 ns | 6.790 ns | 7.283 ns | 12.005 ns | 17.578 ns | 43.136 ns | 119.407 ns | Enables tagged pointer support. |
| `release-compact-headers` | Layout / ABI | 0.96x | 6.684 ns | 11.138 ns | 6.907 ns | 9.796 ns | 14.969 ns | 40.361 ns | 168.756 ns | Uses the compact runtime object header layout. |
| `release-inline-value-storage` | Layout / ABI | 0.92x | 6.604 ns | 11.175 ns | 6.932 ns | 10.427 ns | 16.963 ns | 43.174 ns | 181.278 ns | Enables compact inline ValueObject prefixes and the compact-header prerequisite. |
| `release-inline-group-state` | Layout / ABI | 0.98x | 6.509 ns | 10.915 ns | 6.916 ns | 9.787 ns | 17.098 ns | 40.055 ns | 131.496 ns | Stores parent/group bookkeeping inline and enables the compact-header prerequisite. |
| `release-analysis-symbols` | Instrumentation | 1.02x | 6.182 ns | 10.594 ns | 7.244 ns | 10.034 ns | 15.939 ns | 40.562 ns | 112.304 ns | Keeps debug symbols, disables strip, and emits relocations. |
| `release-native-tuning` | Whole-program | 1.01x | 8.827 ns | 9.028 ns | 7.590 ns | 9.274 ns | 13.778 ns | 40.429 ns | 116.249 ns | Enables -march=native and -mtune=native. |
| `release-thinlto` | Whole-program | 1.59x | 5.550 ns | 6.609 ns | 6.773 ns | 5.874 ns | 5.966 ns | 25.529 ns | 67.783 ns | Enables ThinLTO. |
| `release-full-lto` | Whole-program | 1.88x | 5.313 ns | 5.800 ns | 3.044 ns | 3.916 ns | 6.933 ns | 27.051 ns | 66.806 ns | Enables full LTO. |

### ObjFW ABI Debug

| Variant | Category | Geo Mean vs `debug-default` | dispatch_monomorphic_hot | dispatch_polymorphic_hot | arc_retain_release_heap | arc_retain_release_round_robin | arc_store_strong_cycle | alloc_init_release_plain | parent_group_cycle | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `debug-default` | Modes | 1.00x | 24.077 ns | 24.196 ns | 20.007 ns | 36.936 ns | 41.735 ns | 144.634 ns | 413.465 ns | Debug build with runtime defaults. This is the debug baseline. |
| `debug-dispatch-c` | Dispatch / behavior | 0.99x | 24.063 ns | 24.180 ns | 21.148 ns | 36.558 ns | 41.414 ns | 141.888 ns | 424.718 ns | Uses the C message send path instead of the assembly fast path. |
| `debug-exceptions-off` | Dispatch / behavior | 1.00x | 25.085 ns | 24.820 ns | 20.460 ns | 35.166 ns | 39.202 ns | 135.018 ns | 443.171 ns | Disables Objective-C exceptions support. |
| `debug-reflection-off` | Dispatch / behavior | 1.02x | 23.839 ns | 24.026 ns | 20.043 ns | 35.280 ns | 40.755 ns | 140.741 ns | 411.218 ns | Disables reflection support. |
| `debug-forwarding` | Dispatch / behavior | 0.95x | 28.479 ns | 27.993 ns | 20.047 ns | 35.473 ns | 39.592 ns | 141.706 ns | 493.086 ns | Enables forwarding and the cold miss path. |
| `debug-validation` | Dispatch / behavior | 0.97x | 24.120 ns | 23.875 ns | 21.411 ns | 33.955 ns | 45.605 ns | 152.715 ns | 445.340 ns | Adds defensive object validation checks. |
| `debug-tagged-pointers` | Dispatch / behavior | 0.94x | 25.259 ns | 24.916 ns | 20.077 ns | 40.529 ns | 55.539 ns | 140.198 ns | 427.313 ns | Enables tagged pointer support. |
| `debug-compact-headers` | Layout / ABI | 0.88x | 24.029 ns | 24.137 ns | 21.072 ns | 36.095 ns | 43.547 ns | 176.802 ns | 786.176 ns | Uses the compact runtime object header layout. |
| `debug-inline-value-storage` | Layout / ABI | 0.84x | 23.947 ns | 24.045 ns | 20.340 ns | 38.260 ns | 49.357 ns | 197.177 ns | 864.681 ns | Enables compact inline ValueObject prefixes and the compact-header prerequisite. |
| `debug-inline-group-state` | Layout / ABI | 0.90x | 25.093 ns | 24.417 ns | 21.196 ns | 36.166 ns | 41.970 ns | 183.050 ns | 646.652 ns | Stores parent/group bookkeeping inline and enables the compact-header prerequisite. |
| `debug-sanitize` | Instrumentation | 0.30x | 50.964 ns | 53.730 ns | 40.461 ns | 151.394 ns | 341.645 ns | 571.090 ns | 1676.757 ns | Enables ASan and UBSan for analysis builds. |

## Baseline Reference

- `gnustep-2.3 release-default`: `/workspaces/smallfw/build/runtime-analysis/performance-matrix-full/runs/release-default-gnustep`
- `gnustep-2.3 debug-default`: `/workspaces/smallfw/build/runtime-analysis/performance-matrix-full/runs/debug-default-gnustep`
- `objfw-1.5 release-default`: `/workspaces/smallfw/build/runtime-analysis/performance-matrix-full/runs/release-default-objfw`
- `objfw-1.5 debug-default`: `/workspaces/smallfw/build/runtime-analysis/performance-matrix-full/runs/debug-default-objfw`
- Matrix JSON: `/workspaces/smallfw/build/runtime-analysis/performance-matrix-full/matrix.json`
