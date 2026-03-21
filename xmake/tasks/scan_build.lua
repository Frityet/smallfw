task("run-scan-build")
    set_category("tool")
    set_menu {
        usage = "xmake run-scan-build [options]",
        description = "Generate a compile database and run the Clang Static Analyzer.",
        options = smallfw.runtime_config_menu_options({
            {},
            {"O", "outdir", "kv", "build/scan-build", "Set the scan-build report directory."},
            {nil, "targets", "kv", "runtime-tests:runtime-bench",
                "Colon-separated target list to analyze."},
            {nil, "report-format", "kv", "html", "Set the scan-build report format.",
                " - html", " - plist", " - plist-html", " - sarif"},
            {nil, "analyze-headers", "kv", "y", "Analyze functions in included headers too.",
                " - y", " - n"},
            {nil, "strict", "kv", "n", "Enable every locally available clang analyzer checker.",
                " - y", " - n"},
            {nil, "ctu", "kv", "n", "Enable cross-translation-unit analysis when supported.",
                " - y", " - n"},
            {nil, "maxloop", "kv", "16", "Set scan-build loop exploration depth."},
        }, {
            mode = "release",
        })
    }
    on_run(function ()
        local runner = import("smallfw.tasks.scan_build")
        runner.main()
    end)
task_end()
