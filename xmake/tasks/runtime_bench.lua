task("run-runtime-bench")
    set_category("tool")
    set_menu {
        usage = "xmake run-runtime-bench [options]",
        description = "Build runtime-bench, run repeated benchmark samples, and record structured results. Recommended fastest combo: --runtime-native-tuning=y --runtime-thinlto=y --runtime-compact-headers=y --runtime-inline-value-storage=y --runtime-inline-group-state=y --pgo=use --bolt=on.",
        options = smallfw.runtime_config_menu_options({
            {},
            {nil, "case", "kv", "all", "Benchmark case to run (or all)."},
            {nil, "iters", "kv", nil, "Override iteration count for each benchmark."},
            {nil, "samples", "kv", "5", "Number of recorded benchmark samples."},
            {nil, "warmups", "kv", "1", "Number of warmup benchmark runs."},
            {nil, "pgo", "kv", "off", "PGO mode for this run.", " - off", " - gen", " - use"},
            {nil, "bolt", "kv", "off", "Apply BOLT to the built runtime-bench binary.", " - off", " - on"},
            {"O", "outdir", "kv", "build/runtime-analysis/bench", "Set the benchmark output root."},
            {nil, "tag", "kv", nil, "Optional run tag. Defaults to a UTC timestamp."},
        }, {
            mode = "release",
            plat = "linux",
            arch = "x86_64",
        })
    }
    on_run(function ()
        local runner = import("smallfw.tasks.runtime_bench")
        runner.main()
    end)
task_end()
