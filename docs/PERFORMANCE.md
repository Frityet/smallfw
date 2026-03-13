# Runtime Performance Matrix

This document is generated from measured `xmake run-runtime-bench` runs on the current host. The matrix compares the selected Objective-C runtime ABIs and uses `analysis-symbols=n` by default so release rows reflect a shipping-style binary unless a row explicitly says otherwise.
Relative speedups are computed against the matching `release-default` baseline inside the same ABI.

Generated at: `2026-03-13T03:16:29Z`
Regenerate with: `xmake run-runtime-performance-matrix --samples=1 --warmups=0 --objc-runtimes=gnustep-2.3 --outdir=build/runtime-analysis/performance-matrix --doc=docs/PERFORMANCE.md`

## Environment

- Host: `linux`
- Architecture: `x86_64`
- Objective-C runtimes benchmarked: `gnustep-2.3`
- `uname -srvm`: `Linux 6.17.7-ba25.fc43.x86_64 #1 SMP PREEMPT_DYNAMIC Mon Jan 19 05:47:43 UTC 2026 x86_64`
- `clang --version`: `Debian clang version 21.1.8 (++20251221033036+2078da43e25a-1~exp1~20251221153213.50)`
- `xmake --version`: `xmake v3.0.7+dev.f9d6d50, A cross-platform build utility based on Lua`
- Samples per variant: `1`
- Warmups per variant: `0`
- Benchmark artifact root: `/workspaces/smallfw/build/runtime-analysis/performance-matrix`

## Variant Definitions

| Variant | ABI | Category | Mode | PGO | BOLT | Changed Options | Status | Failure | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `debug-default` | `gnustep-2.3` | Modes | `debug` | `off` | `off` | `objc-runtime=gnustep-2.3` | ok | - | Debug build with runtime defaults. |
| `release-default` | `gnustep-2.3` | Modes | `release` | `off` | `off` | `objc-runtime=gnustep-2.3` | ok | - | Release build with runtime defaults. This is the matrix baseline. |
| `release-native-tuning` | `gnustep-2.3` | Whole-program | `release` | `off` | `off` | `objc-runtime=gnustep-2.3`, `runtime-native-tuning=y` | ok | - | Enables -march=native and -mtune=native. |
| `release-thinlto` | `gnustep-2.3` | Whole-program | `release` | `off` | `off` | `objc-runtime=gnustep-2.3`, `runtime-thinlto=y` | ok | - | Enables ThinLTO. |
| `release-full-lto` | `gnustep-2.3` | Whole-program | `release` | `off` | `off` | `objc-runtime=gnustep-2.3`, `runtime-full-lto=y` | ok | - | Enables full LTO. |
| `release-pgo-gen` | `gnustep-2.3` | Instrumentation | `release` | `gen` | `off` | `objc-runtime=gnustep-2.3` | ok | - | Instrumentation-only PGO generation build. |
| `release-pgo-use` | `gnustep-2.3` | Whole-program | `release` | `use` | `off` | `objc-runtime=gnustep-2.3` | ok | - | Profile-guided optimization on the default release stack. |
| `release-pgo-use-bolt` | `gnustep-2.3` | Whole-program | `release` | `use` | `on` | `analysis-symbols=y`, `objc-runtime=gnustep-2.3` | ok | - | Default release stack with PGO and BOLT. |
| `release-max-opt` | `gnustep-2.3` | Whole-program | `release` | `off` | `off` | `objc-runtime=gnustep-2.3`, `runtime-native-tuning=y`, `runtime-thinlto=y`, `runtime-compact-headers=y`, `runtime-fast-objects=y`, `runtime-inline-value-storage=y`, `runtime-inline-group-state=y` | ok | - | Recommended tuned release stack without profile feedback. |
| `release-max-opt-pgo` | `gnustep-2.3` | Whole-program | `release` | `use` | `off` | `objc-runtime=gnustep-2.3`, `runtime-native-tuning=y`, `runtime-thinlto=y`, `runtime-compact-headers=y`, `runtime-fast-objects=y`, `runtime-inline-value-storage=y`, `runtime-inline-group-state=y` | ok | - | Recommended tuned release stack with PGO. |
| `release-max-opt-pgo-bolt` | `gnustep-2.3` | Whole-program | `release` | `use` | `on` | `analysis-symbols=y`, `objc-runtime=gnustep-2.3`, `runtime-native-tuning=y`, `runtime-thinlto=y`, `runtime-compact-headers=y`, `runtime-fast-objects=y`, `runtime-inline-value-storage=y`, `runtime-inline-group-state=y` | ok | - | Recommended tuned release stack with PGO and BOLT. |
| `release-dispatch-c` | `gnustep-2.3` | Dispatch / behavior | `release` | `off` | `off` | `objc-runtime=gnustep-2.3`, `dispatch-backend=c` | ok | - | Uses the C message send path instead of the assembly fast path. |
| `release-forwarding` | `gnustep-2.3` | Dispatch / behavior | `release` | `off` | `off` | `objc-runtime=gnustep-2.3`, `runtime-forwarding=y` | ok | - | Enables forwarding and the cold miss path. |
| `release-validation` | `gnustep-2.3` | Dispatch / behavior | `release` | `off` | `off` | `objc-runtime=gnustep-2.3`, `runtime-validation=y` | ok | - | Adds defensive object validation checks. |
| `release-tagged-pointers` | `gnustep-2.3` | Dispatch / behavior | `release` | `off` | `off` | `objc-runtime=gnustep-2.3`, `runtime-tagged-pointers=y` | ok | - | Enables tagged pointer support. |
| `release-exceptions-off` | `gnustep-2.3` | Dispatch / behavior | `release` | `off` | `off` | `objc-runtime=gnustep-2.3`, `runtime-exceptions=n` | ok | - | Disables Objective-C exceptions support. |
| `release-reflection-off` | `gnustep-2.3` | Dispatch / behavior | `release` | `off` | `off` | `objc-runtime=gnustep-2.3`, `runtime-reflection=n` | ok | - | Disables reflection support. |
| `release-compact-headers` | `gnustep-2.3` | Layout / ABI | `release` | `off` | `off` | `objc-runtime=gnustep-2.3`, `runtime-compact-headers=y` | ok | - | Uses the compact runtime object header layout. |
| `release-fast-objects` | `gnustep-2.3` | Layout / ABI | `release` | `off` | `off` | `objc-runtime=gnustep-2.3`, `runtime-compact-headers=y`, `runtime-fast-objects=y` | ok | - | Enables FastObject paths and the compact-header prerequisite. |
| `release-inline-value-storage` | `gnustep-2.3` | Layout / ABI | `release` | `off` | `off` | `objc-runtime=gnustep-2.3`, `runtime-compact-headers=y`, `runtime-inline-value-storage=y` | ok | - | Enables compact inline ValueObject prefixes and the compact-header prerequisite. |
| `release-inline-group-state` | `gnustep-2.3` | Layout / ABI | `release` | `off` | `off` | `objc-runtime=gnustep-2.3`, `runtime-compact-headers=y`, `runtime-inline-group-state=y` | ok | - | Stores parent/group bookkeeping inline and enables the compact-header prerequisite. |
| `release-analysis-symbols` | `gnustep-2.3` | Instrumentation | `release` | `off` | `off` | `analysis-symbols=y`, `objc-runtime=gnustep-2.3` | ok | - | Keeps debug symbols, disables strip, and emits relocations. |
| `release-sanitize` | `gnustep-2.3` | Instrumentation | `release` | `off` | `off` | `objc-runtime=gnustep-2.3`, `runtime-sanitize=y` | ok | - | AddressSanitizer and UndefinedBehaviorSanitizer enabled. |

## Leaderboard

### GNUstep ABI

| Rank | Variant | Category | Geo Mean vs ABI `release-default` | Best Case | Worst Case | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | `release-full-lto` | Whole-program | 1.88x | `arc_store_strong_cycle` (3.42x) | `dispatch_monomorphic_hot` (0.97x) | Enables full LTO. |
| 2 | `release-max-opt-pgo` | Whole-program | 1.70x | `arc_store_strong_cycle` (3.48x) | `dispatch_monomorphic_hot` (0.98x) | Recommended tuned release stack with PGO. |
| 3 | `release-max-opt-pgo-bolt` | Whole-program | 1.68x | `arc_store_strong_cycle` (3.23x) | `dispatch_monomorphic_hot` (0.94x) | Recommended tuned release stack with PGO and BOLT. |
| 4 | `release-thinlto` | Whole-program | 1.66x | `arc_store_strong_cycle` (3.44x) | `dispatch_monomorphic_hot` (0.99x) | Enables ThinLTO. |
| 5 | `release-pgo-use-bolt` | Whole-program | 1.22x | `arc_retain_release_round_robin` (1.62x) | `dispatch_monomorphic_hot` (0.96x) | Default release stack with PGO and BOLT. |
| 6 | `release-pgo-use` | Whole-program | 1.16x | `arc_retain_release_heap` (1.66x) | `parent_group_cycle` (0.95x) | Profile-guided optimization on the default release stack. |
| 7 | `release-max-opt` | Whole-program | 1.12x | `arc_store_strong_cycle` (1.85x) | `parent_group_cycle` (0.84x) | Recommended tuned release stack without profile feedback. |
| 8 | `release-exceptions-off` | Dispatch / behavior | 1.06x | `arc_retain_release_round_robin` (1.20x) | `dispatch_monomorphic_hot` (0.96x) | Disables Objective-C exceptions support. |
| 9 | `release-forwarding` | Dispatch / behavior | 1.03x | `arc_retain_release_round_robin` (1.14x) | `dispatch_polymorphic_hot` (1.00x) | Enables forwarding and the cold miss path. |
| 10 | `release-default` | Modes | 1.00x | `dispatch_monomorphic_hot` (1.00x) | `dispatch_monomorphic_hot` (1.00x) | Release build with runtime defaults. This is the matrix baseline. |
| 11 | `release-reflection-off` | Dispatch / behavior | 0.99x | `dispatch_polymorphic_hot` (1.00x) | `arc_retain_release_heap` (0.95x) | Disables reflection support. |
| 12 | `release-tagged-pointers` | Dispatch / behavior | 0.99x | `arc_retain_release_round_robin` (1.18x) | `dispatch_monomorphic_hot` (0.86x) | Enables tagged pointer support. |
| 13 | `release-analysis-symbols` | Instrumentation | 0.99x | `arc_retain_release_round_robin` (1.01x) | `parent_group_cycle` (0.97x) | Keeps debug symbols, disables strip, and emits relocations. |
| 14 | `release-native-tuning` | Whole-program | 0.98x | `arc_retain_release_round_robin` (1.11x) | `arc_retain_release_heap` (0.93x) | Enables -march=native and -mtune=native. |
| 15 | `release-inline-group-state` | Layout / ABI | 0.98x | `arc_retain_release_round_robin` (1.14x) | `parent_group_cycle` (0.76x) | Stores parent/group bookkeeping inline and enables the compact-header prerequisite. |
| 16 | `release-compact-headers` | Layout / ABI | 0.94x | `arc_retain_release_round_robin` (1.13x) | `parent_group_cycle` (0.65x) | Uses the compact runtime object header layout. |
| 17 | `release-fast-objects` | Layout / ABI | 0.93x | `arc_retain_release_round_robin` (1.14x) | `parent_group_cycle` (0.63x) | Enables FastObject paths and the compact-header prerequisite. |
| 18 | `release-validation` | Dispatch / behavior | 0.93x | `arc_retain_release_round_robin` (1.05x) | `alloc_init_release_plain` (0.79x) | Adds defensive object validation checks. |
| 19 | `release-inline-value-storage` | Layout / ABI | 0.91x | `arc_retain_release_round_robin` (1.12x) | `parent_group_cycle` (0.54x) | Enables compact inline ValueObject prefixes and the compact-header prerequisite. |
| 20 | `release-pgo-gen` | Instrumentation | 0.59x | `arc_retain_release_round_robin` (0.96x) | `parent_group_cycle` (0.24x) | Instrumentation-only PGO generation build. |
| 21 | `debug-default` | Modes | 0.40x | `dispatch_polymorphic_hot` (0.58x) | `parent_group_cycle` (0.29x) | Debug build with runtime defaults. |
| 22 | `release-dispatch-c` | Dispatch / behavior | 0.31x | `arc_retain_release_round_robin` (1.21x) | `dispatch_monomorphic_hot` (0.03x) | Uses the C message send path instead of the assembly fast path. |
| 23 | `release-sanitize` | Instrumentation | 0.18x | `dispatch_polymorphic_hot` (0.29x) | `parent_group_cycle` (0.09x) | AddressSanitizer and UndefinedBehaviorSanitizer enabled. |

## Fastest Variant Per Benchmark

| Benchmark | Fastest Variant | ABI | Mean | Speedup vs ABI `release-default` |
| --- | --- | --- | --- | --- |
| `dispatch_monomorphic_hot` | `release-inline-value-storage` | GNUstep ABI | 0.575 ns | 1.00x |
| `dispatch_polymorphic_hot` | `release-full-lto` | GNUstep ABI | 0.624 ns | 1.07x |
| `arc_retain_release_heap` | `release-full-lto` | GNUstep ABI | 2.916 ns | 2.37x |
| `arc_retain_release_round_robin` | `release-full-lto` | GNUstep ABI | 3.224 ns | 3.25x |
| `arc_store_strong_cycle` | `release-max-opt-pgo` | GNUstep ABI | 4.157 ns | 3.48x |
| `alloc_init_release_plain` | `release-thinlto` | GNUstep ABI | 12.144 ns | 1.75x |
| `parent_group_cycle` | `release-thinlto` | GNUstep ABI | 41.207 ns | 1.83x |

## ASM vs C Backend

| ABI | Benchmark | ASM Mean | C Mean | ASM Advantage |
| --- | --- | --- | --- | --- |
| GNUstep ABI | `dispatch_monomorphic_hot` | 0.577 ns | 18.226 ns | 31.59x |
| GNUstep ABI | `dispatch_polymorphic_hot` | 0.669 ns | 18.240 ns | 27.26x |
| GNUstep ABI | `arc_retain_release_heap` | 6.920 ns | 6.978 ns | 1.01x |
| GNUstep ABI | `arc_retain_release_round_robin` | 10.479 ns | 8.691 ns | 0.83x |
| GNUstep ABI | `arc_store_strong_cycle` | 14.463 ns | 12.591 ns | 0.87x |
| GNUstep ABI | `alloc_init_release_plain` | 21.238 ns | 64.337 ns | 3.03x |
| GNUstep ABI | `parent_group_cycle` | 75.565 ns | 157.766 ns | 2.09x |

## Per-Benchmark Results

### dispatch_monomorphic_hot

| Variant | ABI | Mean | Speedup vs ABI `release-default` | Category | Notes |
| --- | --- | --- | --- | --- | --- |
| `debug-default` | GNUstep ABI | 1.092 ns | 0.53x | Modes | Debug build with runtime defaults. |
| `release-default` | GNUstep ABI | 0.577 ns | 1.00x | Modes | Release build with runtime defaults. This is the matrix baseline. |
| `release-native-tuning` | GNUstep ABI | 0.616 ns | 0.94x | Whole-program | Enables -march=native and -mtune=native. |
| `release-thinlto` | GNUstep ABI | 0.580 ns | 0.99x | Whole-program | Enables ThinLTO. |
| `release-full-lto` | GNUstep ABI | 0.594 ns | 0.97x | Whole-program | Enables full LTO. |
| `release-pgo-gen` | GNUstep ABI | 1.447 ns | 0.40x | Instrumentation | Instrumentation-only PGO generation build. |
| `release-pgo-use` | GNUstep ABI | 0.589 ns | 0.98x | Whole-program | Profile-guided optimization on the default release stack. |
| `release-pgo-use-bolt` | GNUstep ABI | 0.601 ns | 0.96x | Whole-program | Default release stack with PGO and BOLT. |
| `release-max-opt` | GNUstep ABI | 0.580 ns | 0.99x | Whole-program | Recommended tuned release stack without profile feedback. |
| `release-max-opt-pgo` | GNUstep ABI | 0.591 ns | 0.98x | Whole-program | Recommended tuned release stack with PGO. |
| `release-max-opt-pgo-bolt` | GNUstep ABI | 0.611 ns | 0.94x | Whole-program | Recommended tuned release stack with PGO and BOLT. |
| `release-dispatch-c` | GNUstep ABI | 18.226 ns | 0.03x | Dispatch / behavior | Uses the C message send path instead of the assembly fast path. |
| `release-forwarding` | GNUstep ABI | 0.576 ns | 1.00x | Dispatch / behavior | Enables forwarding and the cold miss path. |
| `release-validation` | GNUstep ABI | 0.582 ns | 0.99x | Dispatch / behavior | Adds defensive object validation checks. |
| `release-tagged-pointers` | GNUstep ABI | 0.672 ns | 0.86x | Dispatch / behavior | Enables tagged pointer support. |
| `release-exceptions-off` | GNUstep ABI | 0.601 ns | 0.96x | Dispatch / behavior | Disables Objective-C exceptions support. |
| `release-reflection-off` | GNUstep ABI | 0.579 ns | 1.00x | Dispatch / behavior | Disables reflection support. |
| `release-compact-headers` | GNUstep ABI | 0.607 ns | 0.95x | Layout / ABI | Uses the compact runtime object header layout. |
| `release-fast-objects` | GNUstep ABI | 0.592 ns | 0.97x | Layout / ABI | Enables FastObject paths and the compact-header prerequisite. |
| `release-inline-value-storage` | GNUstep ABI | 0.575 ns | 1.00x | Layout / ABI | Enables compact inline ValueObject prefixes and the compact-header prerequisite. |
| `release-inline-group-state` | GNUstep ABI | 0.584 ns | 0.99x | Layout / ABI | Stores parent/group bookkeeping inline and enables the compact-header prerequisite. |
| `release-analysis-symbols` | GNUstep ABI | 0.596 ns | 0.97x | Instrumentation | Keeps debug symbols, disables strip, and emits relocations. |
| `release-sanitize` | GNUstep ABI | 2.095 ns | 0.28x | Instrumentation | AddressSanitizer and UndefinedBehaviorSanitizer enabled. |

### dispatch_polymorphic_hot

| Variant | ABI | Mean | Speedup vs ABI `release-default` | Category | Notes |
| --- | --- | --- | --- | --- | --- |
| `debug-default` | GNUstep ABI | 1.157 ns | 0.58x | Modes | Debug build with runtime defaults. |
| `release-default` | GNUstep ABI | 0.669 ns | 1.00x | Modes | Release build with runtime defaults. This is the matrix baseline. |
| `release-native-tuning` | GNUstep ABI | 0.668 ns | 1.00x | Whole-program | Enables -march=native and -mtune=native. |
| `release-thinlto` | GNUstep ABI | 0.645 ns | 1.04x | Whole-program | Enables ThinLTO. |
| `release-full-lto` | GNUstep ABI | 0.624 ns | 1.07x | Whole-program | Enables full LTO. |
| `release-pgo-gen` | GNUstep ABI | 1.402 ns | 0.48x | Instrumentation | Instrumentation-only PGO generation build. |
| `release-pgo-use` | GNUstep ABI | 0.683 ns | 0.98x | Whole-program | Profile-guided optimization on the default release stack. |
| `release-pgo-use-bolt` | GNUstep ABI | 0.658 ns | 1.02x | Whole-program | Default release stack with PGO and BOLT. |
| `release-max-opt` | GNUstep ABI | 0.667 ns | 1.00x | Whole-program | Recommended tuned release stack without profile feedback. |
| `release-max-opt-pgo` | GNUstep ABI | 0.673 ns | 0.99x | Whole-program | Recommended tuned release stack with PGO. |
| `release-max-opt-pgo-bolt` | GNUstep ABI | 0.650 ns | 1.03x | Whole-program | Recommended tuned release stack with PGO and BOLT. |
| `release-dispatch-c` | GNUstep ABI | 18.240 ns | 0.04x | Dispatch / behavior | Uses the C message send path instead of the assembly fast path. |
| `release-forwarding` | GNUstep ABI | 0.670 ns | 1.00x | Dispatch / behavior | Enables forwarding and the cold miss path. |
| `release-validation` | GNUstep ABI | 0.667 ns | 1.00x | Dispatch / behavior | Adds defensive object validation checks. |
| `release-tagged-pointers` | GNUstep ABI | 0.670 ns | 1.00x | Dispatch / behavior | Enables tagged pointer support. |
| `release-exceptions-off` | GNUstep ABI | 0.671 ns | 1.00x | Dispatch / behavior | Disables Objective-C exceptions support. |
| `release-reflection-off` | GNUstep ABI | 0.666 ns | 1.00x | Dispatch / behavior | Disables reflection support. |
| `release-compact-headers` | GNUstep ABI | 0.691 ns | 0.97x | Layout / ABI | Uses the compact runtime object header layout. |
| `release-fast-objects` | GNUstep ABI | 0.703 ns | 0.95x | Layout / ABI | Enables FastObject paths and the compact-header prerequisite. |
| `release-inline-value-storage` | GNUstep ABI | 0.675 ns | 0.99x | Layout / ABI | Enables compact inline ValueObject prefixes and the compact-header prerequisite. |
| `release-inline-group-state` | GNUstep ABI | 0.680 ns | 0.98x | Layout / ABI | Stores parent/group bookkeeping inline and enables the compact-header prerequisite. |
| `release-analysis-symbols` | GNUstep ABI | 0.681 ns | 0.98x | Instrumentation | Keeps debug symbols, disables strip, and emits relocations. |
| `release-sanitize` | GNUstep ABI | 2.307 ns | 0.29x | Instrumentation | AddressSanitizer and UndefinedBehaviorSanitizer enabled. |

### arc_retain_release_heap

| Variant | ABI | Mean | Speedup vs ABI `release-default` | Category | Notes |
| --- | --- | --- | --- | --- | --- |
| `debug-default` | GNUstep ABI | 20.247 ns | 0.34x | Modes | Debug build with runtime defaults. |
| `release-default` | GNUstep ABI | 6.920 ns | 1.00x | Modes | Release build with runtime defaults. This is the matrix baseline. |
| `release-native-tuning` | GNUstep ABI | 7.443 ns | 0.93x | Whole-program | Enables -march=native and -mtune=native. |
| `release-thinlto` | GNUstep ABI | 4.870 ns | 1.42x | Whole-program | Enables ThinLTO. |
| `release-full-lto` | GNUstep ABI | 2.916 ns | 2.37x | Whole-program | Enables full LTO. |
| `release-pgo-gen` | GNUstep ABI | 8.632 ns | 0.80x | Instrumentation | Instrumentation-only PGO generation build. |
| `release-pgo-use` | GNUstep ABI | 4.172 ns | 1.66x | Whole-program | Profile-guided optimization on the default release stack. |
| `release-pgo-use-bolt` | GNUstep ABI | 4.614 ns | 1.50x | Whole-program | Default release stack with PGO and BOLT. |
| `release-max-opt` | GNUstep ABI | 7.663 ns | 0.90x | Whole-program | Recommended tuned release stack without profile feedback. |
| `release-max-opt-pgo` | GNUstep ABI | 3.145 ns | 2.20x | Whole-program | Recommended tuned release stack with PGO. |
| `release-max-opt-pgo-bolt` | GNUstep ABI | 3.206 ns | 2.16x | Whole-program | Recommended tuned release stack with PGO and BOLT. |
| `release-dispatch-c` | GNUstep ABI | 6.978 ns | 0.99x | Dispatch / behavior | Uses the C message send path instead of the assembly fast path. |
| `release-forwarding` | GNUstep ABI | 6.928 ns | 1.00x | Dispatch / behavior | Enables forwarding and the cold miss path. |
| `release-validation` | GNUstep ABI | 7.012 ns | 0.99x | Dispatch / behavior | Adds defensive object validation checks. |
| `release-tagged-pointers` | GNUstep ABI | 6.798 ns | 1.02x | Dispatch / behavior | Enables tagged pointer support. |
| `release-exceptions-off` | GNUstep ABI | 6.756 ns | 1.02x | Dispatch / behavior | Disables Objective-C exceptions support. |
| `release-reflection-off` | GNUstep ABI | 7.307 ns | 0.95x | Dispatch / behavior | Disables reflection support. |
| `release-compact-headers` | GNUstep ABI | 6.994 ns | 0.99x | Layout / ABI | Uses the compact runtime object header layout. |
| `release-fast-objects` | GNUstep ABI | 6.861 ns | 1.01x | Layout / ABI | Enables FastObject paths and the compact-header prerequisite. |
| `release-inline-value-storage` | GNUstep ABI | 6.989 ns | 0.99x | Layout / ABI | Enables compact inline ValueObject prefixes and the compact-header prerequisite. |
| `release-inline-group-state` | GNUstep ABI | 6.950 ns | 1.00x | Layout / ABI | Stores parent/group bookkeeping inline and enables the compact-header prerequisite. |
| `release-analysis-symbols` | GNUstep ABI | 6.881 ns | 1.01x | Instrumentation | Keeps debug symbols, disables strip, and emits relocations. |
| `release-sanitize` | GNUstep ABI | 40.016 ns | 0.17x | Instrumentation | AddressSanitizer and UndefinedBehaviorSanitizer enabled. |

### arc_retain_release_round_robin

| Variant | ABI | Mean | Speedup vs ABI `release-default` | Category | Notes |
| --- | --- | --- | --- | --- | --- |
| `debug-default` | GNUstep ABI | 34.136 ns | 0.31x | Modes | Debug build with runtime defaults. |
| `release-default` | GNUstep ABI | 10.479 ns | 1.00x | Modes | Release build with runtime defaults. This is the matrix baseline. |
| `release-native-tuning` | GNUstep ABI | 9.433 ns | 1.11x | Whole-program | Enables -march=native and -mtune=native. |
| `release-thinlto` | GNUstep ABI | 4.872 ns | 2.15x | Whole-program | Enables ThinLTO. |
| `release-full-lto` | GNUstep ABI | 3.224 ns | 3.25x | Whole-program | Enables full LTO. |
| `release-pgo-gen` | GNUstep ABI | 10.870 ns | 0.96x | Instrumentation | Instrumentation-only PGO generation build. |
| `release-pgo-use` | GNUstep ABI | 6.703 ns | 1.56x | Whole-program | Profile-guided optimization on the default release stack. |
| `release-pgo-use-bolt` | GNUstep ABI | 6.469 ns | 1.62x | Whole-program | Default release stack with PGO and BOLT. |
| `release-max-opt` | GNUstep ABI | 8.154 ns | 1.29x | Whole-program | Recommended tuned release stack without profile feedback. |
| `release-max-opt-pgo` | GNUstep ABI | 3.693 ns | 2.84x | Whole-program | Recommended tuned release stack with PGO. |
| `release-max-opt-pgo-bolt` | GNUstep ABI | 3.738 ns | 2.80x | Whole-program | Recommended tuned release stack with PGO and BOLT. |
| `release-dispatch-c` | GNUstep ABI | 8.691 ns | 1.21x | Dispatch / behavior | Uses the C message send path instead of the assembly fast path. |
| `release-forwarding` | GNUstep ABI | 9.177 ns | 1.14x | Dispatch / behavior | Enables forwarding and the cold miss path. |
| `release-validation` | GNUstep ABI | 9.977 ns | 1.05x | Dispatch / behavior | Adds defensive object validation checks. |
| `release-tagged-pointers` | GNUstep ABI | 8.863 ns | 1.18x | Dispatch / behavior | Enables tagged pointer support. |
| `release-exceptions-off` | GNUstep ABI | 8.744 ns | 1.20x | Dispatch / behavior | Disables Objective-C exceptions support. |
| `release-reflection-off` | GNUstep ABI | 10.446 ns | 1.00x | Dispatch / behavior | Disables reflection support. |
| `release-compact-headers` | GNUstep ABI | 9.288 ns | 1.13x | Layout / ABI | Uses the compact runtime object header layout. |
| `release-fast-objects` | GNUstep ABI | 9.188 ns | 1.14x | Layout / ABI | Enables FastObject paths and the compact-header prerequisite. |
| `release-inline-value-storage` | GNUstep ABI | 9.361 ns | 1.12x | Layout / ABI | Enables compact inline ValueObject prefixes and the compact-header prerequisite. |
| `release-inline-group-state` | GNUstep ABI | 9.216 ns | 1.14x | Layout / ABI | Stores parent/group bookkeeping inline and enables the compact-header prerequisite. |
| `release-analysis-symbols` | GNUstep ABI | 10.405 ns | 1.01x | Instrumentation | Keeps debug symbols, disables strip, and emits relocations. |
| `release-sanitize` | GNUstep ABI | 65.120 ns | 0.16x | Instrumentation | AddressSanitizer and UndefinedBehaviorSanitizer enabled. |

### arc_store_strong_cycle

| Variant | ABI | Mean | Speedup vs ABI `release-default` | Category | Notes |
| --- | --- | --- | --- | --- | --- |
| `debug-default` | GNUstep ABI | 31.836 ns | 0.45x | Modes | Debug build with runtime defaults. |
| `release-default` | GNUstep ABI | 14.463 ns | 1.00x | Modes | Release build with runtime defaults. This is the matrix baseline. |
| `release-native-tuning` | GNUstep ABI | 14.833 ns | 0.98x | Whole-program | Enables -march=native and -mtune=native. |
| `release-thinlto` | GNUstep ABI | 4.208 ns | 3.44x | Whole-program | Enables ThinLTO. |
| `release-full-lto` | GNUstep ABI | 4.225 ns | 3.42x | Whole-program | Enables full LTO. |
| `release-pgo-gen` | GNUstep ABI | 15.908 ns | 0.91x | Instrumentation | Instrumentation-only PGO generation build. |
| `release-pgo-use` | GNUstep ABI | 13.073 ns | 1.11x | Whole-program | Profile-guided optimization on the default release stack. |
| `release-pgo-use-bolt` | GNUstep ABI | 10.954 ns | 1.32x | Whole-program | Default release stack with PGO and BOLT. |
| `release-max-opt` | GNUstep ABI | 7.836 ns | 1.85x | Whole-program | Recommended tuned release stack without profile feedback. |
| `release-max-opt-pgo` | GNUstep ABI | 4.157 ns | 3.48x | Whole-program | Recommended tuned release stack with PGO. |
| `release-max-opt-pgo-bolt` | GNUstep ABI | 4.484 ns | 3.23x | Whole-program | Recommended tuned release stack with PGO and BOLT. |
| `release-dispatch-c` | GNUstep ABI | 12.591 ns | 1.15x | Dispatch / behavior | Uses the C message send path instead of the assembly fast path. |
| `release-forwarding` | GNUstep ABI | 13.743 ns | 1.05x | Dispatch / behavior | Enables forwarding and the cold miss path. |
| `release-validation` | GNUstep ABI | 16.540 ns | 0.87x | Dispatch / behavior | Adds defensive object validation checks. |
| `release-tagged-pointers` | GNUstep ABI | 13.773 ns | 1.05x | Dispatch / behavior | Enables tagged pointer support. |
| `release-exceptions-off` | GNUstep ABI | 12.708 ns | 1.14x | Dispatch / behavior | Disables Objective-C exceptions support. |
| `release-reflection-off` | GNUstep ABI | 14.451 ns | 1.00x | Dispatch / behavior | Disables reflection support. |
| `release-compact-headers` | GNUstep ABI | 13.733 ns | 1.05x | Layout / ABI | Uses the compact runtime object header layout. |
| `release-fast-objects` | GNUstep ABI | 13.485 ns | 1.07x | Layout / ABI | Enables FastObject paths and the compact-header prerequisite. |
| `release-inline-value-storage` | GNUstep ABI | 14.187 ns | 1.02x | Layout / ABI | Enables compact inline ValueObject prefixes and the compact-header prerequisite. |
| `release-inline-group-state` | GNUstep ABI | 13.499 ns | 1.07x | Layout / ABI | Stores parent/group bookkeeping inline and enables the compact-header prerequisite. |
| `release-analysis-symbols` | GNUstep ABI | 14.515 ns | 1.00x | Instrumentation | Keeps debug symbols, disables strip, and emits relocations. |
| `release-sanitize` | GNUstep ABI | 55.517 ns | 0.26x | Instrumentation | AddressSanitizer and UndefinedBehaviorSanitizer enabled. |

### alloc_init_release_plain

| Variant | ABI | Mean | Speedup vs ABI `release-default` | Category | Notes |
| --- | --- | --- | --- | --- | --- |
| `debug-default` | GNUstep ABI | 58.194 ns | 0.36x | Modes | Debug build with runtime defaults. |
| `release-default` | GNUstep ABI | 21.238 ns | 1.00x | Modes | Release build with runtime defaults. This is the matrix baseline. |
| `release-native-tuning` | GNUstep ABI | 21.663 ns | 0.98x | Whole-program | Enables -march=native and -mtune=native. |
| `release-thinlto` | GNUstep ABI | 12.144 ns | 1.75x | Whole-program | Enables ThinLTO. |
| `release-full-lto` | GNUstep ABI | 12.590 ns | 1.69x | Whole-program | Enables full LTO. |
| `release-pgo-gen` | GNUstep ABI | 27.054 ns | 0.79x | Instrumentation | Instrumentation-only PGO generation build. |
| `release-pgo-use` | GNUstep ABI | 19.461 ns | 1.09x | Whole-program | Profile-guided optimization on the default release stack. |
| `release-pgo-use-bolt` | GNUstep ABI | 18.329 ns | 1.16x | Whole-program | Default release stack with PGO and BOLT. |
| `release-max-opt` | GNUstep ABI | 17.865 ns | 1.19x | Whole-program | Recommended tuned release stack without profile feedback. |
| `release-max-opt-pgo` | GNUstep ABI | 12.673 ns | 1.68x | Whole-program | Recommended tuned release stack with PGO. |
| `release-max-opt-pgo-bolt` | GNUstep ABI | 12.535 ns | 1.69x | Whole-program | Recommended tuned release stack with PGO and BOLT. |
| `release-dispatch-c` | GNUstep ABI | 64.337 ns | 0.33x | Dispatch / behavior | Uses the C message send path instead of the assembly fast path. |
| `release-forwarding` | GNUstep ABI | 20.956 ns | 1.01x | Dispatch / behavior | Enables forwarding and the cold miss path. |
| `release-validation` | GNUstep ABI | 26.981 ns | 0.79x | Dispatch / behavior | Adds defensive object validation checks. |
| `release-tagged-pointers` | GNUstep ABI | 22.739 ns | 0.93x | Dispatch / behavior | Enables tagged pointer support. |
| `release-exceptions-off` | GNUstep ABI | 19.654 ns | 1.08x | Dispatch / behavior | Disables Objective-C exceptions support. |
| `release-reflection-off` | GNUstep ABI | 21.232 ns | 1.00x | Dispatch / behavior | Disables reflection support. |
| `release-compact-headers` | GNUstep ABI | 23.061 ns | 0.92x | Layout / ABI | Uses the compact runtime object header layout. |
| `release-fast-objects` | GNUstep ABI | 24.469 ns | 0.87x | Layout / ABI | Enables FastObject paths and the compact-header prerequisite. |
| `release-inline-value-storage` | GNUstep ABI | 24.402 ns | 0.87x | Layout / ABI | Enables compact inline ValueObject prefixes and the compact-header prerequisite. |
| `release-inline-group-state` | GNUstep ABI | 22.333 ns | 0.95x | Layout / ABI | Stores parent/group bookkeeping inline and enables the compact-header prerequisite. |
| `release-analysis-symbols` | GNUstep ABI | 21.181 ns | 1.00x | Instrumentation | Keeps debug symbols, disables strip, and emits relocations. |
| `release-sanitize` | GNUstep ABI | 175.928 ns | 0.12x | Instrumentation | AddressSanitizer and UndefinedBehaviorSanitizer enabled. |

### parent_group_cycle

| Variant | ABI | Mean | Speedup vs ABI `release-default` | Category | Notes |
| --- | --- | --- | --- | --- | --- |
| `debug-default` | GNUstep ABI | 263.042 ns | 0.29x | Modes | Debug build with runtime defaults. |
| `release-default` | GNUstep ABI | 75.565 ns | 1.00x | Modes | Release build with runtime defaults. This is the matrix baseline. |
| `release-native-tuning` | GNUstep ABI | 79.400 ns | 0.95x | Whole-program | Enables -march=native and -mtune=native. |
| `release-thinlto` | GNUstep ABI | 41.207 ns | 1.83x | Whole-program | Enables ThinLTO. |
| `release-full-lto` | GNUstep ABI | 42.981 ns | 1.76x | Whole-program | Enables full LTO. |
| `release-pgo-gen` | GNUstep ABI | 310.879 ns | 0.24x | Instrumentation | Instrumentation-only PGO generation build. |
| `release-pgo-use` | GNUstep ABI | 79.690 ns | 0.95x | Whole-program | Profile-guided optimization on the default release stack. |
| `release-pgo-use-bolt` | GNUstep ABI | 68.270 ns | 1.11x | Whole-program | Default release stack with PGO and BOLT. |
| `release-max-opt` | GNUstep ABI | 89.465 ns | 0.84x | Whole-program | Recommended tuned release stack without profile feedback. |
| `release-max-opt-pgo` | GNUstep ABI | 65.947 ns | 1.15x | Whole-program | Recommended tuned release stack with PGO. |
| `release-max-opt-pgo-bolt` | GNUstep ABI | 63.502 ns | 1.19x | Whole-program | Recommended tuned release stack with PGO and BOLT. |
| `release-dispatch-c` | GNUstep ABI | 157.766 ns | 0.48x | Dispatch / behavior | Uses the C message send path instead of the assembly fast path. |
| `release-forwarding` | GNUstep ABI | 75.125 ns | 1.01x | Dispatch / behavior | Enables forwarding and the cold miss path. |
| `release-validation` | GNUstep ABI | 89.716 ns | 0.84x | Dispatch / behavior | Adds defensive object validation checks. |
| `release-tagged-pointers` | GNUstep ABI | 81.108 ns | 0.93x | Dispatch / behavior | Enables tagged pointer support. |
| `release-exceptions-off` | GNUstep ABI | 74.560 ns | 1.01x | Dispatch / behavior | Disables Objective-C exceptions support. |
| `release-reflection-off` | GNUstep ABI | 75.597 ns | 1.00x | Dispatch / behavior | Disables reflection support. |
| `release-compact-headers` | GNUstep ABI | 116.730 ns | 0.65x | Layout / ABI | Uses the compact runtime object header layout. |
| `release-fast-objects` | GNUstep ABI | 120.168 ns | 0.63x | Layout / ABI | Enables FastObject paths and the compact-header prerequisite. |
| `release-inline-value-storage` | GNUstep ABI | 140.418 ns | 0.54x | Layout / ABI | Enables compact inline ValueObject prefixes and the compact-header prerequisite. |
| `release-inline-group-state` | GNUstep ABI | 98.983 ns | 0.76x | Layout / ABI | Stores parent/group bookkeeping inline and enables the compact-header prerequisite. |
| `release-analysis-symbols` | GNUstep ABI | 78.066 ns | 0.97x | Instrumentation | Keeps debug symbols, disables strip, and emits relocations. |
| `release-sanitize` | GNUstep ABI | 834.469 ns | 0.09x | Instrumentation | AddressSanitizer and UndefinedBehaviorSanitizer enabled. |

## Baseline Reference

- `gnustep-2.3`: `/workspaces/smallfw/build/runtime-analysis/performance-matrix/runs/release-default-gnustep`
