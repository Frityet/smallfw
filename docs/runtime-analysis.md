# Runtime Analysis

The x86_64 Linux runtime has two first-class analysis tasks in xmake:

```sh
xmake run_runtime_bench [options]
xmake run_runtime_profile [options]
```

## Benchmark task

`run_runtime_bench` builds `runtime_bench` in a dedicated build directory, runs warmups and repeated samples, and records the results under:

```text
build/runtime-analysis/bench/<tag>/
```

Artifacts:

- `configure.log`: xmake configure output
- `build.log`: xmake build output
- `cases.csv`: benchmark cases and their default iteration counts
- `warmup-*.csv`: raw warmup output
- `sample-*.csv`: raw per-sample benchmark output
- `raw.csv`: merged sample data with one row per sample/case
- `summary.json`: structured per-case aggregates
- `summary.txt`: human-readable aggregate summary
- `metadata.json`: host, compiler, xmake, and runtime option metadata

Useful examples:

```sh
xmake run_runtime_bench --tag=all
xmake run_runtime_bench --case=dispatch_monomorphic_hot --samples=10 --warmups=3 --tag=dispatch-hot
xmake run_runtime_bench --case=arc_retain_release_round_robin --iters=2000000 --warmups=0 --tag=arc-rr
```

## Profile task

`run_runtime_profile` builds an instrumented `runtime_bench` in a dedicated build directory and records profile artifacts under:

```text
build/runtime-analysis/profile/<tag>/
```

The task currently targets Linux x86_64. It auto-selects `perf` when available and permitted by the host kernel, and falls back to `gprof` otherwise.

Build flags:

- `perf`: `-O3 -gdwarf-4 -fno-omit-frame-pointer`
- `gprof`: `-O3 -pg -gdwarf-4 -fno-omit-frame-pointer`

Artifacts:

- `configure.log`: xmake configure output
- `build.log`: xmake build output
- `bench.csv`: raw benchmark timing for the profiled run
- `summary.json`: structured profile summary
- `summary.txt`: human-readable profile summary
- `metadata.json`: host, compiler, xmake, runtime option, and artifact metadata
- `gmon.out`: gprof sampling data when `gprof` is used
- `gprof.txt`: gprof report when `gprof` is used
- `perf.data`, `perf.report.txt`, `perf.record.log`, `perf.stat.txt`: perf artifacts when `perf` is selected
- `objc_msgSend.objdump.txt`: disassembly for the dispatch entry point when `objdump` is available
- `objc_msgSend.s`: extracted assembly input for `llvm-mca`
- `objc_msgSend.llvm-mca.txt`: static pipeline model for the asm dispatcher when `llvm-mca` is available

Useful examples:

```sh
xmake run_runtime_profile --case=dispatch_monomorphic_hot --iters=50000000 --tag=dispatch
xmake run_runtime_profile --case=arc_retain_release_round_robin --iters=2000000 --tag=arc-rr
xmake run_runtime_profile --profiler=perf --case=dispatch_polymorphic_hot --iters=30000000 --tag=dispatch-perf
xmake run_runtime_profile --runtime_slim_alloc=y --case=arc_retain_release_round_robin --iters=2000000 --tag=arc-rr-slim
```

## Slim allocation mode

`runtime_slim_alloc=y` switches the runtime to a compact object header with optional out-of-line metadata for allocator, parent-group, and other uncommon state.

On Linux x86_64, the inline `SFObjHeader_t` shrinks to 32 bytes in slim mode. The full runtime test suite runs against both the default and slim configurations.
