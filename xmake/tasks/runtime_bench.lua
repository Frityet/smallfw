task("run_runtime_bench")
    set_category("tool")
    set_menu {
        usage = "xmake run_runtime_bench [options]",
        description = "Build runtime_bench, run repeated benchmark samples, and record structured results.",
        options = smallfw_runtime_config_menu_options({
            {},
            {nil, "case", "kv", "all", "Benchmark case to run (or all)."},
            {nil, "iters", "kv", nil, "Override iteration count for each benchmark."},
            {nil, "samples", "kv", "5", "Number of recorded benchmark samples."},
            {nil, "warmups", "kv", "1", "Number of warmup benchmark runs."},
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
