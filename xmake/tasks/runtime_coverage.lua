task("run_runtime_coverage")
    set_category("tool")
    set_menu {
        usage = "xmake run_runtime_coverage [options]",
        description = "Build the runtime coverage matrix and enforce the runtime coverage gate.",
        options = {
            {"o", "outdir", "kv", "build/cov-matrix", "Set the coverage output directory."},
        }
    }
    on_run(function ()
        local runner = import("smallfw.tasks.runtime_coverage")
        runner.main()
    end)
task_end()
