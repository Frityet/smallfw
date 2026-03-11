function smallfw_runtime_config_menu_options(extra_options, defaults)
    defaults = defaults or {}
    local options = {
        {"m", "mode", "kv", defaults.mode or "debug", "Set build mode."},
        {"p", "plat", "kv", defaults.plat, "Set target platform."},
        {"a", "arch", "kv", defaults.arch, "Set target architecture."},
        {"o", "builddir", "kv", nil, "Set xmake build directory."},
        {},
        {nil, "runtime-threadsafe", "kv", nil, "Override runtime-threadsafe.", " - y", " - n"},
        {nil, "dispatch-backend", "kv", nil, "Override dispatch-backend.", " - asm", " - c"},
        {nil, "dispatch-stats", "kv", nil, "Override dispatch-stats.", " - y", " - n"},
        {nil, "runtime-exceptions", "kv", nil, "Override runtime-exceptions.", " - y", " - n"},
        {nil, "runtime-reflection", "kv", nil, "Override runtime-reflection.", " - y", " - n"},
        {nil, "runtime-forwarding", "kv", nil, "Override runtime-forwarding.", " - y", " - n"},
        {nil, "runtime-validation", "kv", nil, "Override runtime-validation.", " - y", " - n"},
        {nil, "runtime-tagged-pointers", "kv", nil, "Override runtime-tagged-pointers.", " - y", " - n"},
        {nil, "runtime-sanitize", "kv", nil, "Override runtime-sanitize.", " - y", " - n"},
        {nil, "runtime-slim-alloc", "kv", nil, "Override runtime-slim-alloc.", " - y", " - n"},
    }

    for _, entry in ipairs(extra_options or {}) do
        table.insert(options, entry)
    end
    return options
end
