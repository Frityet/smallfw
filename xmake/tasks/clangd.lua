task("generate-clangd")
    set_category("tool")
    set_menu {
        usage = "xmake generate-clangd",
        description = "Regenerate the project .clangd file.",
        options = {}
    }
    on_run(function ()
        local clangd = import("smallfw.clangd")
        clangd.write_config()
    end)
task_end()

task("check-clangd")
    set_category("tool")
    set_menu {
        usage = "xmake check-clangd [options]",
        description = "Run clangd --check over every SmallFW C, Objective-C, and C++ source/header file.",
        options = {
            {nil, "clear-cache", "kv", "y", "Clear the clangd module cache before checking.", " - y", " - n"},
        }
    }
    on_run(function ()
        local option = import("core.base.option")
        local clangd = import("smallfw.clangd")
        clangd.check_all({clear_cache = option.get("clear-cache") ~= "n"})
    end)
task_end()
