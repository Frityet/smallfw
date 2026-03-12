task("run-runtime-sanitize")
    set_category("tool")
    set_menu {
        usage = "xmake run-runtime-sanitize [options]",
        description = "Build and run runtime tests with validation, AddressSanitizer, and UndefinedBehaviorSanitizer enabled.",
        options = smallfw.runtime_config_menu_options({
            {},
            {"C", "case", "kv", nil, "Run a single runtime test case instead of --all."},
        }, {mode = "debug", plat = "linux", arch = "x86_64"})
    }
    on_run(function ()
        local runner = import("smallfw.tasks.runtime_sanitize")
        runner.main()
    end)
task_end()
