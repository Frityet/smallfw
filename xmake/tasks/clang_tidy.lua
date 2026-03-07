task("run_clang_tidy")
    set_category("tool")
    set_menu {
        usage = "xmake run_clang_tidy [options]",
        description = "Configure the project, regenerate compile_commands, and run clang-tidy.",
        options = smallfw_runtime_config_menu_options({
            {},
            {nil, "tidy_checks", "kv", nil, "Pass --checks to xmake check clang.tidy."},
            {nil, "tidy_configfile", "kv", nil, "Pass --configfile to xmake check clang.tidy."},
            {nil, "tidy_file", "kv", nil, "Pass -f to xmake check clang.tidy."},
            {nil, "tidy_target", "kv", nil, "Check only one target."},
            {nil, "tidy_create", "k", nil, "Pass --create to xmake check clang.tidy."},
            {nil, "tidy_fix", "k", nil, "Pass --fix to xmake check clang.tidy."},
            {nil, "tidy_fix_errors", "k", nil, "Pass --fix_errors to xmake check clang.tidy."},
            {nil, "tidy_fix_notes", "k", nil, "Pass --fix_notes to xmake check clang.tidy."},
        })
    }
    on_run(function ()
        local runner = import("smallfw.tasks.clang_tidy")
        runner.main()
    end)
task_end()
