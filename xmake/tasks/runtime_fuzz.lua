task("run-runtime-fuzz")
    set_category("tool")
    set_menu {
        usage = "xmake run-runtime-fuzz [options]",
        description = "Build and run a runtime libFuzzer harness with validation and sanitizers enabled.",
        options = smallfw.runtime_config_menu_options({
            {},
            {"t", "target", "kv", "dispatch", "Select fuzz harness target.", " - dispatch", " - loader", " - exceptions"},
            {"r", "runs", "kv", "10000", "Set the libFuzzer -runs count."},
            {"c", "corpus", "kv", nil, "Optional corpus directory passed to libFuzzer."},
        }, {mode = "debug", plat = "linux", arch = "x86_64"})
    }
    on_run(function ()
        local runner = import("smallfw.tasks.runtime_fuzz")
        runner.main()
    end)
task_end()
