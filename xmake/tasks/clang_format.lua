task("clang-format")
    set_category("tool")
    set_menu {
        usage = "xmake clang-format [options] [files ...]",
        description = "Format project C/Objective-C sources with the repo's clang-format language overrides.",
        options = {
            {"c", "check", "k", nil, "Check formatting without modifying files."},
            {},
            {nil, "files", "vs", nil, "Files or glob patterns to format. Defaults to src/tests/benchmarks/examples."},
        }
    }
    on_run(function ()
        local runner = import("smallfw.tasks.clang_format")
        runner.main()
    end)
task_end()
