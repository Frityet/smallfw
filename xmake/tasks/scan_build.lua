task("__scan_build_targets")
    on_run(function ()
        local helpers = import("smallfw.task_helpers")
        helpers.run_xmake({"b", "runtime_tests"})
        helpers.run_xmake({"b", "example"})
    end)
task_end()

task("run_scan_build")
    set_category("tool")
    set_menu {
        usage = "xmake run_scan_build [options]",
        description = "Configure the project and run scan-build across runtime_tests and example.",
        options = smallfw_runtime_config_menu_options({
            {},
            {"O", "outdir", "kv", "build/scan-build", "Set the scan-build report directory."},
        })
    }
    on_run(function ()
        local runner = import("smallfw.tasks.scan_build")
        runner.main()
    end)
task_end()
