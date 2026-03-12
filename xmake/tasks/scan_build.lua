task("__scan-build-targets")
    on_run(function ()
        local helpers = import("smallfw.task_helpers")
        helpers.run_xmake({"b", "runtime-tests"})
        helpers.run_xmake({"b", "value-object-demo"})
    end)
task_end()

task("run-scan-build")
    set_category("tool")
    set_menu {
        usage = "xmake run-scan-build [options]",
        description = "Configure the project and run scan-build across runtime-tests and value-object-demo.",
        options = smallfw.runtime_config_menu_options({
            {},
            {"O", "outdir", "kv", "build/scan-build", "Set the scan-build report directory."},
        })
    }
    on_run(function ()
        local runner = import("smallfw.tasks.scan_build")
        runner.main()
    end)
task_end()
