task("run-runtime-profile")
    set_category("tool")
    set_menu {
        usage = "xmake run-runtime-profile [options]",
        description = "Build an instrumented runtime-bench, capture profile artifacts, and record metadata.",
        options = smallfw_runtime_config_menu_options({
            {},
            {nil, "case", "kv", "dispatch_monomorphic_hot", "Benchmark case to profile."},
            {nil, "iters", "kv", nil, "Override iteration count for the profiled benchmark."},
            {nil, "profiler", "kv", "auto", "Profiler backend to use.", " - auto", " - gprof", " - perf"},
            {"O", "outdir", "kv", "build/runtime-analysis/profile", "Set the profile output root."},
            {nil, "tag", "kv", nil, "Optional run tag. Defaults to a UTC timestamp."},
        }, {
            mode = "debug",
            plat = "linux",
            arch = "x86_64",
        })
    }
    on_run(function ()
        local runner = import("smallfw.tasks.runtime_profile")
        runner.main()
    end)
task_end()
